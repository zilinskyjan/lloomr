# LLM call layer.
#
# Replaces upstream llm.py / llm_openai.py. Chat calls go through ellmer
# (provider-agnostic, concurrent via parallel_chat_structured); embeddings
# use a small httr2 client for the OpenAI API since ellmer does not provide
# embeddings. Cost/token accounting uses ellmer::token_usage() snapshots
# instead of upstream's hand-maintained per-model token tables.

# Internal indirection so tests can mock the network call
ll_parallel_impl <- function(chat, prompts, type, max_active, rpm) {
  ellmer::parallel_chat_structured(
    chat = chat,
    prompts = as.list(prompts),
    type = type,
    convert = FALSE,
    max_active = max_active,
    rpm = rpm,
    on_error = "continue"
  )
}

#' Run many structured LLM queries concurrently
#'
#' The workhorse behind every LLooM operator (replaces upstream
#' `multi_query_gpt_wrapper()`). Sends all prompts concurrently through
#' [ellmer::parallel_chat_structured()] with the given output schema and
#' returns one parsed result per prompt. Failed queries yield `NULL` (with a
#' warning) rather than aborting the batch, mirroring upstream behavior.
#'
#' @param chat An ellmer chat object, e.g. `ellmer::chat_openai()`.
#' @param prompts Character vector or list of prompt strings.
#' @param type An ellmer type spec describing the response shape
#'   (see [lloom_type()]).
#' @param max_active Maximum number of simultaneous requests. Default 10.
#' @param rpm Requests-per-minute throttle. Default 500.
#' @return A list with one element per prompt: the parsed result (a list
#'   matching `type`), or `NULL` if that query failed. Token/cost usage for
#'   the call is attached as attribute `"usage"` (a data frame, or `NULL`
#'   when unavailable).
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
#' prompts <- sapply(c("The economy is improving.", "Media trust is falling."),
#'   function(ex) render_prompt(
#'     lloom_prompt("distill_summarize"),
#'     list(ex = ex, seeding_phrase = "", n_bullets = 2, n_words = "3-5")
#'   ))
#' res <- ll_query(chat, prompts, lloom_type("distill_summarize"))
#' str(res)
#' attr(res, "usage")  # tokens and dollars
#' }
ll_query <- function(chat, prompts, type, max_active = 10, rpm = 500) {
  stopifnot(length(prompts) > 0)
  if (is.character(prompts)) prompts <- as.list(prompts)
  stopifnot(all(vapply(prompts, is.character, logical(1))))

  usage_snapshot <- function() {
    tryCatch(
      suppressMessages(ellmer::token_usage()),
      error = function(e) NULL
    )
  }
  usage_before <- usage_snapshot()
  results <- ll_parallel_impl(chat, prompts, type, max_active, rpm)
  usage_after <- usage_snapshot()

  # Failed queries surface as NULL or condition objects; normalize to NULL
  results <- lapply(results, function(x) {
    if (is.null(x) || inherits(x, "condition") || !is.list(x)) NULL else x
  })
  n_failed <- sum(vapply(results, is.null, logical(1)))
  if (n_failed > 0) {
    cli::cli_warn("{n_failed}/{length(results)} LLM quer{?y/ies} failed; returning NULL for those.")
  }

  attr(results, "usage") <- usage_delta(usage_before, usage_after)
  results
}

#' Strip vctrs classes (e.g. ellmer_dollars) so usage columns are plain numeric
#' @noRd
normalize_usage <- function(u) {
  if (is.null(u) || !is.data.frame(u)) {
    return(u)
  }
  for (col in setdiff(names(u), c("provider", "model"))) {
    if (!is.character(u[[col]])) u[[col]] <- as.numeric(u[[col]])
  }
  u
}

#' Compute the change in session token usage between two snapshots
#' @noRd
usage_delta <- function(before, after) {
  before <- normalize_usage(before)
  after <- normalize_usage(after)
  if (is.null(after) || !is.data.frame(after) || nrow(after) == 0) {
    return(NULL)
  }
  num_cols <- intersect(c("input", "output", "cached_input", "price"), names(after))
  num_cols <- num_cols[vapply(after[num_cols], is.numeric, logical(1))]
  if (is.null(before) || !is.data.frame(before) || nrow(before) == 0) {
    return(after)
  }
  key <- c("provider", "model")
  merged <- merge(after, before, by = key, all.x = TRUE, suffixes = c("", "_before"))
  for (col in num_cols) {
    prev <- merged[[paste0(col, "_before")]]
    prev[is.na(prev)] <- 0
    merged[[col]] <- merged[[col]] - prev
  }
  delta <- merged[, c(key, num_cols), drop = FALSE]
  delta[rowSums(delta[, intersect(c("input", "output"), num_cols), drop = FALSE]) > 0, , drop = FALSE]
}

#' Sum the usage attributes accumulated across ll_query calls
#'
#' @param usage_list List of usage data frames (attributes from [ll_query()]).
#' @return A single combined usage data frame, or `NULL`.
#' @noRd
combine_usage <- function(usage_list) {
  usage_list <- purrr::compact(usage_list)
  if (length(usage_list) == 0) {
    return(NULL)
  }
  combined <- dplyr::bind_rows(usage_list)
  num_cols <- names(combined)[vapply(combined, is.numeric, logical(1))]
  dplyr::summarise(
    combined,
    dplyr::across(dplyr::all_of(num_cols), ~ sum(.x, na.rm = TRUE)),
    .by = dplyr::all_of(c("provider", "model"))
  )
}

# EMBEDDINGS ================================

# Internal indirection so tests can mock the network call.
# Returns a list of numeric vectors, one per input text.
ll_embed_request <- function(texts, model, api_key, base_url, dimensions = NULL) {
  body <- list(model = model, input = as.list(texts))
  if (!is.null(dimensions)) body$dimensions <- dimensions

  resp <- httr2::request(base_url) |>
    httr2::req_url_path_append("embeddings") |>
    httr2::req_auth_bearer_token(api_key) |>
    httr2::req_body_json(body) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_timeout(120) |>
    httr2::req_perform() |>
    httr2::resp_body_json()

  lapply(resp$data, function(d) as.numeric(unlist(d$embedding)))
}

#' Embed texts with the OpenAI embeddings API
#'
#' Replaces upstream `get_embeddings()` / `call_embed_fn()`. Newlines are
#' replaced with spaces (as upstream, since they can degrade embedding
#' quality) and requests are batched. Any operator that takes an `embed_fn`
#' argument accepts a drop-in replacement with this signature, so other
#' embedding providers (or precomputed embeddings) can be used.
#'
#' @param texts Character vector of texts to embed.
#' @param model OpenAI embedding model name. Default
#'   `"text-embedding-3-large"` (the upstream default for clustering).
#' @param api_key API key; defaults to the `OPENAI_API_KEY` environment
#'   variable.
#' @param batch_size Maximum texts per request. Default 2048 (upstream
#'   default; also the OpenAI API maximum).
#' @param dimensions Optional reduced dimensionality (supported by
#'   text-embedding-3 models).
#' @param base_url API base URL (override for Azure/compatible endpoints).
#' @return A numeric matrix with `length(texts)` rows.
#' @export
#' @examples
#' \dontrun{
#' emb <- ll_embed(c("politics and elections", "sports scores"),
#'                 model = "text-embedding-3-small")
#' dim(emb)
#' }
ll_embed <- function(texts,
                     model = "text-embedding-3-large",
                     api_key = Sys.getenv("OPENAI_API_KEY"),
                     batch_size = 2048,
                     dimensions = NULL,
                     base_url = "https://api.openai.com/v1") {
  stopifnot(is.character(texts), length(texts) > 0)
  if (!nzchar(api_key)) {
    cli::cli_abort("No API key. Set the {.envvar OPENAI_API_KEY} environment variable or pass {.arg api_key}.")
  }

  texts_clean <- gsub("\n", " ", texts, fixed = TRUE)
  batch_starts <- seq(1, length(texts_clean), by = batch_size)

  embeddings <- purrr::list_flatten(purrr::map(batch_starts, function(start) {
    batch <- texts_clean[start:min(start + batch_size - 1, length(texts_clean))]
    ll_embed_request(batch, model, api_key, base_url, dimensions)
  }))

  if (length(embeddings) != length(texts)) {
    cli::cli_abort(
      "Embedding API returned {length(embeddings)} vectors for {length(texts)} texts."
    )
  }
  do.call(rbind, embeddings)
}
