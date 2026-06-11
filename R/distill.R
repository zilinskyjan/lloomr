# Distill operators: filter (extract quotes) and summarize (bullet points).
# Mirrors distill_filter() and distill_summarize() in upstream
# concept_induction.py.

#' Distill documents to salient quotes
#'
#' For each document, asks the LLM to extract `n_quotes` quotes copied
#' verbatim from the text (the optional `seed` steers which quotes count as
#' relevant). This is the first, optional step of the LLooM pipeline,
#' typically used for long documents; short texts (e.g. social media posts)
#' can skip straight to [distill_summarize()].
#'
#' @param df Data frame of documents.
#' @param text_col,id_col Column names (strings) for document text and IDs.
#' @param chat An ellmer chat object used for the LLM calls.
#' @param n_quotes Number of quotes to extract per document. Default 3.
#' @param seed Optional seed term to steer extraction (e.g. "media distrust").
#' @param prompt_template Optional custom template; must contain the fields
#'   required by `validate_prompt("distill_filter", ...)`.
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A tibble with columns `id_col` and `text_col`, where `text_col`
#'   now holds the extracted quotes (newline-separated), one row per
#'   document. Documents whose query failed are dropped (with a warning).
#'   Token/cost usage is attached as attribute `"usage"`.
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
#' quotes <- distill_filter(df, "text", "doc_id", chat, n_quotes = 2)
#' }
distill_filter <- function(df,
                           text_col,
                           id_col,
                           chat,
                           n_quotes = 3,
                           seed = NULL,
                           prompt_template = NULL,
                           max_active = 10,
                           rpm = 500) {
  if (is.null(prompt_template)) {
    prompt_template <- lloom_prompt("distill_filter")
  } else {
    validate_prompt("distill_filter", prompt_template)
  }
  df <- filter_empty_rows(df, text_col)
  stopifnot(nrow(df) > 0)

  prompts <- vapply(
    df[[text_col]],
    function(ex) render_prompt(prompt_template, list(
      ex = ex,
      n_quotes = n_quotes,
      seeding_phrase = seeding_phrase(seed, "distill_filter")
    )),
    character(1),
    USE.NAMES = FALSE
  )

  results <- ll_query(chat, prompts, lloom_type("distill_filter"),
                      max_active = max_active, rpm = rpm)

  quotes <- vapply(results, function(res) {
    if (is.null(res) || length(res$relevant_quotes) == 0) {
      NA_character_
    } else {
      paste(unlist(res$relevant_quotes), collapse = "\n")
    }
  }, character(1))

  out <- tibble::tibble(
    !!id_col := as.character(df[[id_col]]),
    !!text_col := quotes
  )
  out <- out[!is.na(out[[text_col]]), , drop = FALSE]
  attr(out, "usage") <- attr(results, "usage")
  out
}

#' Distill documents to bullet-point summaries
#'
#' For each document (or its quotes from [distill_filter()]), asks the LLM
#' for `n_bullets` short bullet-point summaries. Bullets are the unit that
#' gets clustered and synthesized into concepts downstream.
#'
#' @inheritParams distill_filter
#' @param n_bullets Number of bullets per document; a number or a range
#'   string like `"2-4"` (upstream default).
#' @param n_words_per_bullet Length of each bullet; a number or range string
#'   like `"5-8"` (upstream default).
#' @return A tibble with columns `id_col` and `text_col`, **one row per
#'   bullet** (document IDs repeat). Documents whose query failed are
#'   dropped (with a warning). Token/cost usage is attached as attribute
#'   `"usage"`.
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
#' bullets <- distill_summarize(df, "text", "doc_id", chat, n_bullets = "1-2",
#'                              seed = "media trust")
#' }
distill_summarize <- function(df,
                              text_col,
                              id_col,
                              chat,
                              n_bullets = "2-4",
                              n_words_per_bullet = "5-8",
                              seed = NULL,
                              prompt_template = NULL,
                              max_active = 10,
                              rpm = 500) {
  if (is.null(prompt_template)) {
    prompt_template <- lloom_prompt("distill_summarize")
  } else {
    validate_prompt("distill_summarize", prompt_template)
  }
  df <- filter_empty_rows(df, text_col)
  stopifnot(nrow(df) > 0)

  prompts <- vapply(
    df[[text_col]],
    function(ex) render_prompt(prompt_template, list(
      ex = ex,
      seeding_phrase = seeding_phrase(seed, "distill_summarize"),
      n_bullets = n_bullets,
      n_words = n_words_per_bullet
    )),
    character(1),
    USE.NAMES = FALSE
  )

  results <- ll_query(chat, prompts, lloom_type("distill_summarize"),
                      max_active = max_active, rpm = rpm)

  ids <- as.character(df[[id_col]])
  rows <- purrr::map2(ids, results, function(ex_id, res) {
    if (is.null(res) || length(res$bullets) == 0) {
      return(NULL)
    }
    tibble::tibble(
      !!id_col := ex_id,
      !!text_col := unlist(res$bullets)
    )
  })

  out <- dplyr::bind_rows(purrr::compact(rows))
  attr(out, "usage") <- attr(results, "usage")
  out
}
