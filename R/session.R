# Session object and one-call pipeline.
# Mirrors the `lloom` workbench class in upstream workbench.py, redesigned
# functionally: lloom_session() builds a plain S3 object, and each step
# (lloom_gen(), lloom_score(), ...) returns an updated copy. Every operator
# also remains usable standalone on data frames.
#
# Deviations from upstream (deliberate):
# - No interactive y/n confirmation inside gen()/score(); cost estimation
#   is available separately via lloom_estimate_gen_cost() /
#   lloom_estimate_score_cost().
# - `sample_n` (lloomr extension): concept generation may run on a random
#   sample while scoring runs on the full dataset.
# - Sentence counting for parameter suggestion uses a regex heuristic
#   rather than nltk.

#' Create a LLooM session
#'
#' Bundles the data, the models for each pipeline step, and (as the
#' pipeline runs) all intermediate and final results. Step functions
#' ([lloom_gen()], [lloom_score()]) take and return the session, so the
#' idiom is `sess <- lloom_gen(sess, ...)`.
#'
#' @param df Data frame with one row per document.
#' @param text_col Name of the text column.
#' @param id_col Name of the document ID column; if `NULL`, an `id` column
#'   of row numbers is created (with a message). IDs must be unique.
#' @param chat Optional: a single ellmer chat object to use for **all**
#'   LLM steps. This is where the model and provider are chosen — any
#'   ellmer provider works ([ellmer::chat_openai()],
#'   [ellmer::chat_anthropic()], [ellmer::chat_google_gemini()],
#'   [ellmer::chat_ollama()], ...). Overridden by the step-specific
#'   arguments below.
#' @param distill_chat,synth_chat,score_chat ellmer chat objects for the
#'   distill, synthesize/review, and score steps individually (a common
#'   pattern: a cheap model for the high-volume distill/score steps, a
#'   capable one for synthesis). Defaults when neither these nor `chat`
#'   are given: gpt-5.4-nano for distill/score and gpt-5.2 for synthesis
#'   (requires `OPENAI_API_KEY`). Upstream's defaults were gpt-4o-mini /
#'   gpt-4o; lloomr tracks newer models (deviation D10 in the comparison
#'   document).
#'
#' @details
#' Note on embeddings: clustering uses OpenAI embeddings by default
#' regardless of the chat provider (Anthropic, for example, has no
#' embeddings API). To use another embedding provider — or precomputed
#' embeddings — supply `embed_fn`.
#' @param embed_fn Embedding function for clustering (see [cluster_texts()]).
#'   Default: [ll_embed()] with `embed_model`.
#' @param embed_model Embedding model for the default `embed_fn`.
#' @return An object of class `lloom_session`.
#' @export
#' @examples
#' \dontrun{
#' # Default models (OpenAI):
#' sess <- lloom_session(df, text_col = "text", id_col = "doc_id")
#'
#' # One model of your choice for every step — this is where you pick
#' # the LLM (any ellmer provider):
#' sess <- lloom_session(df, "text", "doc_id",
#'   chat = ellmer::chat_anthropic(model = "claude-haiku-4-5", echo = "none")
#' )
#'
#' # Or per step (cheap model for high-volume steps, capable for synthesis):
#' sess <- lloom_session(
#'   df, "text", "doc_id",
#'   distill_chat = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none"),
#'   synth_chat   = ellmer::chat_openai(model = "gpt-5.2", echo = "none"),
#'   score_chat   = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
#' )
#' }
lloom_session <- function(df,
                          text_col,
                          id_col = NULL,
                          chat = NULL,
                          distill_chat = NULL,
                          synth_chat = NULL,
                          score_chat = NULL,
                          embed_fn = NULL,
                          embed_model = "text-embedding-3-large") {
  stopifnot(is.data.frame(df), text_col %in% names(df))

  if (is.null(id_col)) {
    cli::cli_inform("No {.arg id_col} provided; created an ID column named {.field id}.")
    id_col <- "id"
    df[[id_col]] <- seq_len(nrow(df))
  }
  stopifnot(id_col %in% names(df))

  n_orig <- nrow(df)
  df <- df[!is.na(df[[id_col]]) & !is.na(df[[text_col]]), , drop = FALSE]
  if (nrow(df) < n_orig) {
    cli::cli_inform("Dropped {n_orig - nrow(df)} row{?s} with missing ID or text.")
  }
  stopifnot(nrow(df) > 0)
  if (anyDuplicated(df[[id_col]])) {
    cli::cli_abort("Column {.field {id_col}} has duplicated values; document IDs must be unique.")
  }
  df[[id_col]] <- as.character(df[[id_col]])

  sess <- list(
    df = tibble::as_tibble(df),
    text_col = text_col,
    id_col = id_col,
    distill_chat = distill_chat %||% chat %||%
      ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none"),
    synth_chat = synth_chat %||% chat %||%
      ellmer::chat_openai(model = "gpt-5.2", echo = "none"),
    score_chat = score_chat %||% chat %||%
      ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none"),
    embed_fn = embed_fn %||% function(t) ll_embed(t, model = embed_model),
    params = NULL,
    df_filtered = NULL,
    df_bullets = NULL,
    clusters = NULL,
    concepts = NULL,
    assignments = NULL,
    score_df = NULL,
    history = list()
  )
  class(sess) <- "lloom_session"
  sess
}

#' Count sentences with a simple regex heuristic
#' @noRd
count_sentences <- function(texts) {
  vapply(texts, function(t) {
    pieces <- strsplit(t, "[.!?]+(\\s+|$)")[[1]]
    max(1L, sum(nchar(trimws(pieces)) > 0))
  }, integer(1), USE.NAMES = FALSE)
}

#' Suggest concept-generation parameters
#'
#' Heuristic parameter suggestion (mirrors upstream
#' `auto_suggest_parameters()`): quotes per document scale with the median
#' sentence count; bullets scale with quotes; concepts per cluster aim for
#' `target_n_concepts` overall across an assumed ~3 clusters.
#'
#' @param sess A [lloom_session()].
#' @param target_n_concepts Desired total number of generated concepts.
#'   Default 20 (upstream).
#' @return A list: `filter_n_quotes`, `summ_n_bullets`, `synth_n_concepts`.
#' @export
#' @examples
#' \dontrun{
#' params <- lloom_suggest_params(sess)
#' sess <- lloom_gen(sess, params = params)
#' }
lloom_suggest_params <- function(sess, target_n_concepts = 20) {
  stopifnot(inherits(sess, "lloom_session"))
  n_sents <- count_sentences(sess$df[[sess$text_col]])
  med_sents <- stats::median(n_sents)
  filter_n_quotes <- max(1, ceiling(med_sents * 0.75))
  summ_n_bullets <- max(1, floor(filter_n_quotes * 0.75))
  synth_n_concepts <- max(1, floor(target_n_concepts / 3))
  list(
    filter_n_quotes = filter_n_quotes,
    summ_n_bullets = summ_n_bullets,
    synth_n_concepts = synth_n_concepts
  )
}

#' Append a step record to the session history
#' @noRd
record_step <- function(sess, step, started, usage) {
  sess$history[[length(sess$history) + 1]] <- list(
    step = step,
    seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
    usage = usage
  )
  sess
}

#' Generate concepts: distill, cluster, synthesize, review
#'
#' Runs the inductive half of the pipeline (upstream `gen()`):
#' optionally filter to quotes, summarize to bullets, cluster, synthesize
#' concepts per cluster, and auto-review (remove + merge; with
#' `max_concepts`, also select). The quote-filtering step is skipped when
#' `params$filter_n_quotes <= 1` (typical for short texts).
#'
#' @param sess A [lloom_session()].
#' @param seed Optional seed term steering all generation steps.
#' @param params Parameter list as from [lloom_suggest_params()]; `NULL` =
#'   auto-suggest (with a message).
#' @param n_synth Number of synthesize iterations; iterations after the
#'   first re-cluster the previous round's concepts (upstream behavior).
#'   Default 1.
#' @param max_concepts If supplied, [review_select()] activates the best
#'   subset at the end.
#' @param auto_review Run remove + merge review after synthesis. Default
#'   `TRUE`.
#' @param sample_n Optional: generate concepts from a random sample of this
#'   many documents (scoring still uses the full data). lloomr extension.
#' @param verbose Announce steps. Default `TRUE`.
#' @return The updated session (fields `df_filtered`, `df_bullets`,
#'   `clusters`, `concepts`, `assignments`, `params`, `history`).
#' @export
#' @examples
#' \dontrun{
#' # Generate concepts from a 200-doc sample, steered toward a topic,
#' # and activate the best 8
#' sess <- lloom_gen(sess, seed = "media trust", sample_n = 200,
#'                   max_concepts = 8)
#' sess$concepts
#' }
lloom_gen <- function(sess,
                      seed = NULL,
                      params = NULL,
                      n_synth = 1,
                      max_concepts = NULL,
                      auto_review = TRUE,
                      sample_n = NULL,
                      verbose = TRUE) {
  stopifnot(inherits(sess, "lloom_session"))
  say <- function(msg) if (verbose) cli::cli_inform(msg)

  if (is.null(params)) {
    params <- lloom_suggest_params(sess)
    say("Auto-suggested parameters: filter_n_quotes = {params$filter_n_quotes}, summ_n_bullets = {params$summ_n_bullets}, synth_n_concepts = {params$synth_n_concepts}")
  }
  sess$params <- params

  gen_df <- sess$df
  if (!is.null(sample_n) && sample_n < nrow(gen_df)) {
    gen_df <- gen_df[sample.int(nrow(gen_df), sample_n), , drop = FALSE]
    say("Generating concepts from a sample of {sample_n} documents.")
  }

  # Distill: filter (optional) ---------------------------------------
  if (params$filter_n_quotes > 1) {
    say("Distill: filtering to quotes ...")
    started <- Sys.time()
    sess$df_filtered <- distill_filter(
      gen_df, sess$text_col, sess$id_col, sess$distill_chat,
      n_quotes = params$filter_n_quotes, seed = seed
    )
    sess <- record_step(sess, "distill_filter", started, attr(sess$df_filtered, "usage"))
  } else {
    say("Distill: skipping quote filter (filter_n_quotes <= 1).")
    sess$df_filtered <- tibble::tibble(
      !!sess$id_col := as.character(gen_df[[sess$id_col]]),
      !!sess$text_col := gen_df[[sess$text_col]]
    )
  }

  # Distill: summarize ------------------------------------------------
  say("Distill: summarizing to bullets ...")
  started <- Sys.time()
  sess$df_bullets <- distill_summarize(
    sess$df_filtered, sess$text_col, sess$id_col, sess$distill_chat,
    n_bullets = params$summ_n_bullets, seed = seed
  )
  sess <- record_step(sess, "distill_summarize", started, attr(sess$df_bullets, "usage"))

  # Synthesize iterations ---------------------------------------------
  cluster_in <- sess$df_bullets
  synth_n <- params$synth_n_concepts
  for (i in seq_len(n_synth)) {
    say("Cluster (iteration {i}) ...")
    started <- Sys.time()
    sess$clusters <- cluster_texts(
      cluster_in, sess$text_col, sess$id_col, embed_fn = sess$embed_fn
    )
    sess <- record_step(sess, paste0("cluster_", i), started, NULL)

    say("Synthesize (iteration {i}) ...")
    started <- Sys.time()
    synth <- synthesize_concepts(
      sess$clusters, sess$text_col, sess$id_col, sess$synth_chat,
      n_concepts = synth_n, pattern_phrase = "unique topic", seed = seed
    )
    sess <- record_step(sess, paste0("synthesize_", i), started, attr(synth, "usage"))
    sess$concepts <- synth$concepts
    sess$assignments <- synth$assignments

    if (auto_review && nrow(sess$concepts) > 0) {
      say("Review (iteration {i}) ...")
      started <- Sys.time()
      reviewed <- review_concepts(
        sess$concepts, sess$synth_chat,
        assignments = sess$assignments, seed = seed
      )
      sess <- record_step(sess, paste0("review_", i), started, NULL)
      sess$concepts <- reviewed$concepts
      sess$assignments <- reviewed$assignments
      if (verbose && length(reviewed$removed) > 0) {
        cli::cli_inform("Review removed: {.val {reviewed$removed}}")
      }
      if (verbose && nrow(reviewed$merged) > 0) {
        cli::cli_inform("Review merged {nrow(reviewed$merged)} pair{?s}.")
      }
    }

    # Next iteration re-synthesizes from the current concepts (upstream)
    if (i < n_synth) {
      cluster_in <- tibble::tibble(
        !!sess$id_col := sess$assignments[[sess$id_col]],
        !!sess$text_col := paste0(
          sess$assignments$concept_name, ": ", sess$assignments$concept_prompt
        )
      )
      synth_n <- max(1, floor(synth_n * 0.75))
    }
  }

  if (!is.null(max_concepts) && nrow(sess$concepts) > 0) {
    say("Selecting up to {max_concepts} concepts ...")
    started <- Sys.time()
    sess$concepts <- review_select(sess$concepts, max_concepts, sess$synth_chat)
    sess <- record_step(sess, "review_select", started, NULL)
  }

  say("Done: {nrow(sess$concepts)} concept{?s} ({sum(sess$concepts$active)} active).")
  sess
}

#' Score documents against the session's active concepts
#'
#' Runs [score_concepts()] for the session (upstream `score()`): active
#' concepts only, against the full dataset (or `df`).
#'
#' @param sess A [lloom_session()] after [lloom_gen()].
#' @param batch_size Documents per LLM call. Default 1 (upstream session
#'   default; raise for cheaper, slightly less reliable scoring).
#' @param get_highlights Request supporting quotes. Default `TRUE`
#'   (upstream session default).
#' @param score_all Activate and score *all* concepts. Default `FALSE`.
#' @param df Optional alternative document set to score.
#' @param verbose Announce steps. Default `TRUE`.
#' @return The updated session (field `score_df`).
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_score(sess)                  # active concepts, full data
#' sess <- lloom_score(sess, score_all = TRUE)  # every generated concept
#'
#' # Save the resulting scores:
#' readr::write_csv(lloom_results(sess), "scores.csv")
#' }
lloom_score <- function(sess,
                        batch_size = 1,
                        get_highlights = TRUE,
                        score_all = FALSE,
                        df = NULL,
                        verbose = TRUE) {
  stopifnot(inherits(sess, "lloom_session"))
  if (is.null(sess$concepts) || nrow(sess$concepts) == 0) {
    cli::cli_abort("No concepts in session. Run {.fn lloom_gen} first.")
  }
  if (score_all) {
    sess$concepts$active <- TRUE
  }
  active <- sess$concepts[sess$concepts$active, , drop = FALSE]
  if (nrow(active) == 0) {
    cli::cli_abort(c(
      "No active concepts to score.",
      "i" = "Activate concepts with {.code lloom_select(sess, max_concepts)}, set {.code sess$concepts$active} directly, or call with {.code score_all = TRUE}."
    ))
  }

  if (verbose) {
    cli::cli_inform("Scoring {nrow(active)} concept{?s} on {nrow(df %||% sess$df)} document{?s} ...")
  }
  started <- Sys.time()
  sess$score_df <- score_concepts(
    df %||% sess$df, sess$text_col, sess$id_col, active, sess$score_chat,
    batch_size = batch_size, get_highlights = get_highlights
  )
  sess <- record_step(sess, "score", started, attr(sess$score_df, "usage"))
  sess
}

#' Activate the best concepts in a session
#'
#' Convenience wrapper around [review_select()] (upstream `select_auto()`).
#'
#' @param sess A [lloom_session()] after [lloom_gen()].
#' @param max_concepts Maximum number of concepts to activate.
#' @return The updated session.
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_select(sess, max_concepts = 5)
#' }
lloom_select <- function(sess, max_concepts) {
  stopifnot(inherits(sess, "lloom_session"), nrow(sess$concepts) > 0)
  sess$concepts <- review_select(sess$concepts, max_concepts, sess$synth_chat)
  sess
}

#' Add a manual concept to a session
#'
#' Adds a user-defined concept (active by default), e.g. a theory-driven
#' category the model did not propose (upstream `add()`, without the
#' automatic scoring).
#'
#' @param sess A [lloom_session()].
#' @param name,prompt Concept name and inclusion-criterion question.
#' @param active Whether the concept starts active. Default `TRUE`.
#' @return The updated session.
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_add_concept(
#'   sess,
#'   name = "Conspiratorial Framing",
#'   prompt = "Does the text frame events as a hidden coordinated plot?"
#' )
#' }
lloom_add_concept <- function(sess, name, prompt, active = TRUE) {
  stopifnot(inherits(sess, "lloom_session"))
  concept <- new_concepts(name, prompt, active = active)
  sess$concepts <- if (is.null(sess$concepts)) concept else {
    out <- dplyr::bind_rows(sess$concepts, concept)
    class(out) <- c("lloom_concepts", class(tibble::tibble()))
    out
  }
  sess
}

#' Get the score results from a session
#'
#' Returns the long score table: one row per (document, concept) pair with
#' the document ID, concept name, score, rationale, and highlight. It is a
#' plain tibble, so saving it is one line — see the examples. For one row
#' per document (to join onto your main dataset), reshape with
#' [scores_wide()]; to save everything a finished analysis produced in one
#' call, use [lloom_write()].
#'
#' @param sess A [lloom_session()] after [lloom_score()].
#' @return The long score tibble (see [score_concepts()]).
#' @export
#' @examples
#' \dontrun{
#' score_df <- lloom_results(sess)
#'
#' # Save the scores as a CSV (document IDs, concepts, scores, rationales):
#' readr::write_csv(score_df, "scores.csv")
#'
#' # Or one row per document, one column per concept:
#' readr::write_csv(scores_wide(score_df, "doc_id"), "scores_wide.csv")
#' }
lloom_results <- function(sess) {
  stopifnot(inherits(sess, "lloom_session"))
  if (is.null(sess$score_df)) {
    cli::cli_abort("No scores in session. Run {.fn lloom_score} first.")
  }
  sess$score_df
}

#' Generate, select, and score in one call
#'
#' Convenience pipeline (upstream `gen_auto()`): [lloom_gen()] with
#' selection of `max_concepts`, then [lloom_score()].
#'
#' @inheritParams lloom_gen
#' @inheritParams lloom_score
#' @return The updated session.
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_session(df, "text", "doc_id")
#' sess <- lloom_gen_auto(sess, max_concepts = 8)
#' lloom_results(sess)
#' }
lloom_gen_auto <- function(sess,
                           max_concepts = 8,
                           seed = NULL,
                           params = NULL,
                           n_synth = 1,
                           sample_n = NULL,
                           batch_size = 1,
                           get_highlights = TRUE,
                           verbose = TRUE) {
  sess <- lloom_gen(sess, seed = seed, params = params, n_synth = n_synth,
                    max_concepts = max_concepts, sample_n = sample_n,
                    verbose = verbose)
  lloom_score(sess, batch_size = batch_size, get_highlights = get_highlights,
              verbose = verbose)
}

#' Summarize a session's steps, timing, and cost
#'
#' @param object A [lloom_session()].
#' @param ... Unused.
#' @return A tibble: one row per executed step with seconds, tokens, and
#'   price (price `NA` where the provider reports none).
#' @export
#' @examples
#' \dontrun{
#' summary(sess)  # step | seconds | input_tokens | output_tokens | price
#' }
summary.lloom_session <- function(object, ...) {
  if (length(object$history) == 0) {
    return(tibble::tibble(
      step = character(0), seconds = numeric(0),
      input_tokens = numeric(0), output_tokens = numeric(0), price = numeric(0)
    ))
  }
  dplyr::bind_rows(lapply(object$history, function(h) {
    u <- normalize_usage(h$usage)
    tibble::tibble(
      step = h$step,
      seconds = round(h$seconds, 2),
      input_tokens = if (is.null(u)) NA_real_ else sum(u$input, na.rm = TRUE),
      output_tokens = if (is.null(u)) NA_real_ else sum(u$output, na.rm = TRUE),
      price = if (is.null(u) || !"price" %in% names(u)) NA_real_ else as.numeric(sum(u$price, na.rm = TRUE))
    )
  }))
}

#' @export
print.lloom_session <- function(x, ...) {
  cat(sprintf("<lloom_session>: %d documents (text: %s, id: %s)\n",
              nrow(x$df), x$text_col, x$id_col))
  if (!is.null(x$concepts) && nrow(x$concepts) > 0) {
    cat(sprintf("Concepts: %d (%d active)\n", nrow(x$concepts), sum(x$concepts$active)))
  } else {
    cat("Concepts: none (run lloom_gen())\n")
  }
  if (!is.null(x$score_df)) {
    cat(sprintf("Scores: %d (document x concept) rows\n", nrow(x$score_df)))
  }
  if (length(x$history) > 0) {
    s <- summary(x)
    cat(sprintf("Steps run: %s\n", paste(s$step, collapse = ", ")))
    cat(sprintf("Total time: %.1fs | Total cost: $%.4f\n",
                sum(s$seconds), sum(s$price, na.rm = TRUE)))
  }
  invisible(x)
}

# COST ESTIMATION ===========================================================

#' Look up per-token prices for a chat's model (dollars per token)
#' @noRd
model_prices <- function(chat) {
  tryCatch({
    model <- chat$get_model()
    models <- ellmer::models_openai()
    row <- models[models$id == model, , drop = FALSE]
    if (nrow(row) == 0) {
      return(c(input = NA_real_, output = NA_real_))
    }
    c(input = row$input[1] / 1e6, output = row$output[1] / 1e6)
  }, error = function(e) c(input = NA_real_, output = NA_real_))
}

#' Rough token count: ~4 characters per token
#' @noRd
estimate_tokens <- function(texts) {
  ceiling(sum(nchar(texts)) / 4)
}

#' Estimate the cost of concept generation
#'
#' Pre-flight cost estimate for [lloom_gen()] (mirrors upstream
#' `estimate_gen_cost()`, with token counts approximated as characters/4
#' and prices looked up live from the provider's model list where
#' available). Estimates are rough; treat as order-of-magnitude.
#'
#' @param sess A [lloom_session()].
#' @param params Parameter list; `NULL` = auto-suggest.
#' @return A tibble with one row per step: estimated input/output tokens
#'   and dollars (`NA` when the model's price is unknown).
#' @export
#' @examples
#' \dontrun{
#' lloom_estimate_gen_cost(sess)  # before committing to lloom_gen()
#' }
lloom_estimate_gen_cost <- function(sess, params = NULL) {
  stopifnot(inherits(sess, "lloom_session"))
  params <- params %||% lloom_suggest_params(sess)
  n_docs <- nrow(sess$df)
  doc_tokens <- estimate_tokens(sess$df[[sess$text_col]])

  # Empirical per-unit estimates, as upstream
  quote_tokens <- 40 * params$filter_n_quotes
  bullet_tokens <- 10 * params$summ_n_bullets
  est_n_clusters <- 4
  concept_tokens <- 40

  filter_prompt_tokens <- estimate_tokens(lloom_prompt("distill_filter")) * n_docs
  summ_prompt_tokens <- estimate_tokens(lloom_prompt("distill_summarize")) * n_docs
  synth_prompt_tokens <- estimate_tokens(lloom_prompt("synthesize")) * est_n_clusters

  run_filter <- params$filter_n_quotes > 1
  steps <- tibble::tibble(
    step = c("distill_filter", "distill_summarize", "synthesize", "review"),
    chat = c("distill", "distill", "synth", "synth"),
    input_tokens = c(
      if (run_filter) doc_tokens + filter_prompt_tokens else 0,
      (if (run_filter) quote_tokens * n_docs else doc_tokens) + summ_prompt_tokens,
      synth_prompt_tokens + bullet_tokens * n_docs,
      2 * params$synth_n_concepts * est_n_clusters * concept_tokens
    ),
    output_tokens = c(
      if (run_filter) quote_tokens * n_docs else 0,
      bullet_tokens * n_docs,
      params$synth_n_concepts * est_n_clusters * concept_tokens,
      params$synth_n_concepts * est_n_clusters * concept_tokens
    )
  )

  p_distill <- model_prices(sess$distill_chat)
  p_synth <- model_prices(sess$synth_chat)
  steps$dollars <- ifelse(
    steps$chat == "distill",
    steps$input_tokens * p_distill["input"] + steps$output_tokens * p_distill["output"],
    steps$input_tokens * p_synth["input"] + steps$output_tokens * p_synth["output"]
  )
  steps$chat <- NULL
  steps
}

#' Estimate the cost of scoring
#'
#' Pre-flight cost estimate for [lloom_score()] (mirrors upstream
#' `estimate_score_cost()`).
#'
#' @param sess A [lloom_session()].
#' @param n_concepts Number of concepts to score; default = currently
#'   active concepts (or all, if none active).
#' @param batch_size Documents per call (affects prompt overhead).
#' @param df Optional alternative document set.
#' @return A one-row tibble: estimated input/output tokens and dollars.
#' @export
#' @examples
#' \dontrun{
#' lloom_estimate_score_cost(sess, n_concepts = 8)
#' }
lloom_estimate_score_cost <- function(sess, n_concepts = NULL, batch_size = 1, df = NULL) {
  stopifnot(inherits(sess, "lloom_session"))
  df <- df %||% sess$df
  if (is.null(n_concepts)) {
    n_concepts <- if (!is.null(sess$concepts) && sum(sess$concepts$active) > 0) {
      sum(sess$concepts$active)
    } else if (!is.null(sess$concepts)) {
      nrow(sess$concepts)
    } else {
      1
    }
  }

  doc_tokens <- estimate_tokens(df[[sess$text_col]])
  prompt_tokens <- estimate_tokens(lloom_prompt("score_highlight"))
  n_batches <- ceiling(nrow(df) / batch_size)
  score_json_tokens <- 100  # per document, as upstream

  input_tokens <- n_concepts * (doc_tokens + n_batches * (prompt_tokens + 20))
  output_tokens <- n_concepts * nrow(df) * score_json_tokens

  p <- model_prices(sess$score_chat)
  tibble::tibble(
    step = "score",
    input_tokens = input_tokens,
    output_tokens = output_tokens,
    dollars = input_tokens * p["input"] + output_tokens * p["output"]
  )
}
