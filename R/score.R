# Score operator: rate every document against every concept.
# Mirrors score_concepts(), score_helper(), get_score_df(),
# get_empty_score_df(), and summarize_concept() in upstream
# concept_induction.py.

#' Score documents against concepts
#'
#' The deductive step of LLooM: every document is rated against every
#' concept's inclusion criterion on a 5-point scale (A "strongly agree" ...
#' E "strongly disagree", mapped to 1, 0.75, 0.5, 0.25, 0 by
#' [letter_to_score()]). Documents are scored in batches per concept, and
#' all concept-batches run concurrently in a single [ll_query()] call.
#'
#' Every (document, concept) pair is guaranteed to appear exactly once in
#' the output: pairs missing from LLM responses (failed queries, skipped
#' IDs) are backfilled with score 0 and empty rationale, as upstream.
#'
#' @param df Data frame of documents to score (typically the full dataset,
#'   even if concepts were generated from a sample).
#' @param text_col,id_col Column names (strings) for document text and IDs.
#' @param concepts Concept tibble (see [new_concepts()]). All rows are
#'   scored; filter to `active` concepts first if that is what you want
#'   (the session pipeline does this automatically).
#' @param chat An ellmer chat object (high-volume step; a cheap model like
#'   gpt-4o-mini is the upstream default).
#' @param batch_size Documents per LLM call. Default 5 (upstream default;
#'   upstream's session pipeline uses 1).
#' @param get_highlights If `TRUE`, also ask for a supporting quote from
#'   each example (stored in `highlight`). Default `FALSE`.
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A tibble with one row per (document, concept) pair: `id_col`,
#'   `text`, `concept_id`, `concept_name`, `concept_prompt`, `score`,
#'   `rationale`, `highlight`, `concept_seed`. Token/cost usage is attached
#'   as attribute `"usage"`.
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
#' concepts <- new_concepts(
#'   "Vaccine Promotion",
#'   "Does the text promote or encourage vaccination?"
#' )
#' score_df <- score_concepts(df, "text", "doc_id", concepts, chat,
#'                            get_highlights = TRUE)
#' # Prevalence: fraction of documents matching each concept
#' aggregate(score >= 1 ~ concept_name, data = score_df, FUN = mean)
#'
#' # The result is a plain tibble; save it like any data frame:
#' readr::write_csv(score_df, "scores.csv")
#' }
score_concepts <- function(df,
                           text_col,
                           id_col,
                           concepts,
                           chat,
                           batch_size = 5,
                           get_highlights = FALSE,
                           max_active = 10,
                           rpm = 500) {
  validate_concepts(concepts)
  stopifnot(nrow(concepts) > 0)
  df <- filter_empty_rows(df, text_col)
  stopifnot(nrow(df) > 0)

  doc_ids <- as.character(df[[id_col]])
  stopifnot(!anyDuplicated(doc_ids))
  doc_texts <- df[[text_col]]
  step <- if (get_highlights) "score_highlight" else "score"
  prompt_template <- lloom_prompt(step)

  # Build one prompt per (concept, document-batch)
  batch_starts <- seq(1, length(doc_ids), by = batch_size)
  prompt_meta <- purrr::list_flatten(purrr::map(seq_len(nrow(concepts)), function(ci) {
    purrr::map(batch_starts, function(s) {
      idx <- s:min(s + batch_size - 1, length(doc_ids))
      batch_df <- df[idx, , drop = FALSE]
      list(
        concept_i = ci,
        batch_ids = doc_ids[idx],
        prompt = render_prompt(prompt_template, list(
          examples_json = examples_to_json(batch_df, id_col, text_col),
          concept_name = concepts$name[ci],
          concept_prompt = concepts$prompt[ci]
        ))
      )
    })
  }))

  prompts <- vapply(prompt_meta, function(m) m$prompt, character(1))
  results <- ll_query(chat, prompts, lloom_type(step),
                      max_active = max_active, rpm = rpm)

  # Parse responses; keep only example_ids that exist in the batch
  parsed <- purrr::map2(results, prompt_meta, function(res, meta) {
    if (is.null(res) || length(res$pattern_results) == 0) {
      return(NULL)
    }
    rows <- purrr::map(res$pattern_results, function(ex) {
      ex_id <- as.character(ex$example_id %||% "")
      if (!ex_id %in% meta$batch_ids) {
        return(NULL)
      }
      tibble::tibble(
        !!id_col := ex_id,
        concept_i = meta$concept_i,
        score = letter_to_score(ex$answer %||% ""),
        rationale = as.character(ex$rationale %||% ""),
        highlight = as.character(ex$quote %||% "")
      )
    })
    dplyr::bind_rows(purrr::compact(rows))
  })
  scored <- dplyr::bind_rows(purrr::compact(parsed))

  # Assemble the full grid; backfill pairs the LLM missed with NAN_SCORE
  grid <- tidyr::expand_grid(
    concept_i = seq_len(nrow(concepts)),
    doc_i = seq_along(doc_ids)
  )
  grid[[id_col]] <- doc_ids[grid$doc_i]

  if (nrow(scored) > 0) {
    scored <- scored[!duplicated(scored[, c(id_col, "concept_i")]), , drop = FALSE]
    out <- dplyr::left_join(grid, scored, by = c(id_col, "concept_i"))
  } else {
    out <- grid
    out$score <- NA_real_
    out$rationale <- NA_character_
    out$highlight <- NA_character_
  }
  n_backfilled <- sum(is.na(out$score))
  if (n_backfilled > 0) {
    cli::cli_warn(
      "{n_backfilled} (document, concept) pair{?s} missing from LLM responses; backfilled with score 0."
    )
  }
  out$score[is.na(out$score)] <- NAN_SCORE
  out$rationale[is.na(out$rationale)] <- ""
  out$highlight[is.na(out$highlight)] <- ""

  out <- tibble::tibble(
    !!id_col := out[[id_col]],
    text = doc_texts[out$doc_i],
    concept_id = concepts$id[out$concept_i],
    concept_name = concepts$name[out$concept_i],
    concept_prompt = concepts$prompt[out$concept_i],
    score = out$score,
    rationale = out$rationale,
    highlight = out$highlight,
    concept_seed = concepts$seed[out$concept_i]
  )

  # Defensive: exactly one row per (document, concept) pair
  stopifnot(
    nrow(out) == length(doc_ids) * nrow(concepts),
    !anyDuplicated(out[, c(id_col, "concept_id")])
  )

  attr(out, "usage") <- attr(results, "usage")
  out
}

#' Summarize a concept from its matching examples
#'
#' Generates a brief executive summary of one concept from the examples that
#' matched it (mirrors upstream `summarize_concept()`). By default it
#' summarizes the highlight quotes, so scoring should have been run with
#' `get_highlights = TRUE`; set `examples_col = "text"` to summarize the
#' full matched documents instead.
#'
#' @param score_df Output of [score_concepts()].
#' @param concept_id ID of the concept to summarize.
#' @param chat An ellmer chat object.
#' @param threshold Minimum score counting as a match. Default 1 (upstream).
#' @param summary_length Length instruction. Default `"15-20 word"`.
#' @param examples_col Column with the example texts to summarize. Default
#'   `"highlight"`.
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A summary string, or `NA_character_` if the concept has no
#'   matches (or the query fails).
#' @export
#' @examples
#' \dontrun{
#' summarize_concept(score_df, concepts$id[1], chat)
#' }
summarize_concept <- function(score_df,
                              concept_id,
                              chat,
                              threshold = 1,
                              summary_length = "15-20 word",
                              examples_col = "highlight",
                              max_active = 10,
                              rpm = 500) {
  matched <- score_df[score_df$concept_id == concept_id & score_df$score >= threshold, , drop = FALSE]
  examples <- matched[[examples_col]]
  examples <- examples[!is.na(examples) & nchar(examples) > 0]
  if (nrow(matched) == 0 || length(examples) == 0) {
    return(NA_character_)
  }
  examples <- sample(examples)  # shuffle, as upstream

  prompt <- render_prompt(lloom_prompt("summarize_concept"), list(
    summary_length = summary_length,
    concept_name = matched$concept_name[1],
    examples = paste("-", examples, collapse = "\n")
  ))
  res <- ll_query(chat, prompt, lloom_type("summarize_concept"),
                  max_active = max_active, rpm = rpm)[[1]]
  if (is.null(res$summary)) NA_character_ else as.character(res$summary)
}
