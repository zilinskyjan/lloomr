# Shared helpers used across LLooM pipeline stages.
# Mirrors helper functions in upstream concept_induction.py.

# Numerical score used in place of unparseable/missing values
# (upstream NAN_SCORE)
NAN_SCORE <- 0

# Criteria string attached to the synthetic "Outlier" concept
OUTLIER_CRITERIA <- "Did the example not match any of the above concepts?"

#' Convert A-E Likert letters to numeric scores
#'
#' Maps the multiple-choice answers used in scoring prompts to numeric scores
#' (mirrors `parse_bucketed_score()` upstream): A = 1, B = 0.75, C = 0.5,
#' D = 0.25, E = 0. Only the first character is used, case-insensitively;
#' anything unrecognized becomes 0 (the upstream `NAN_SCORE` convention).
#'
#' @param x Character vector of answers (e.g. `c("A", "b", "E: disagree")`).
#' @return Numeric vector of the same length.
#' @export
#' @examples
#' letter_to_score(c("A", "b", "C.", "junk", NA))
letter_to_score <- function(x) {
  first <- toupper(substr(trimws(as.character(x)), 1, 1))
  scores <- c(A = 1, B = 0.75, C = 0.5, D = 0.25, E = 0)
  out <- unname(scores[first])
  out[is.na(out)] <- NAN_SCORE
  out
}

#' Drop rows whose text column is missing or empty
#'
#' Mirrors `filter_empty_rows()` upstream: removes rows where the given
#' column is `NA` or a zero-length string.
#'
#' @param df A data frame.
#' @param text_col Name of the text column (string).
#' @return The filtered data frame.
#' @export
#' @examples
#' df <- data.frame(id = 1:3, text = c("keep me", "", NA))
#' filter_empty_rows(df, "text")
filter_empty_rows <- function(df, text_col) {
  stopifnot(text_col %in% names(df))
  txt <- df[[text_col]]
  keep <- !is.na(txt) & nchar(txt) > 0
  df[keep, , drop = FALSE]
}

#' Format documents as the JSON examples block used in scoring prompts
#'
#' Produces `{"cur_examples": [{"example_id": ..., "example_text": ...}, ...]}`,
#' mirroring `get_examples_dict()` + `dict_to_json()` upstream. No brace
#' escaping is needed because [render_prompt()] does not re-interpolate
#' inserted values.
#'
#' @param df Data frame of documents.
#' @param id_col,text_col Column names (strings) for document IDs and text.
#' @return A length-1 JSON string.
#' @export
#' @examples
#' df <- data.frame(doc_id = 1:2, text = c("First post.", "Second post."))
#' examples_to_json(df, "doc_id", "text")
examples_to_json <- function(df, id_col, text_col) {
  stopifnot(all(c(id_col, text_col) %in% names(df)))
  ex_list <- purrr::map2(
    as.character(df[[id_col]]), df[[text_col]],
    function(id, text) list(example_id = id, example_text = text)
  )
  as.character(jsonlite::toJSON(list(cur_examples = ex_list), auto_unbox = TRUE))
}

#' Robustly parse a JSON object out of an LLM text response
#'
#' Fallback parser for non-structured responses (mirrors `json_load()`
#' upstream): trims to the outermost `{...}` (dropping markdown fences or
#' chatter around the JSON), parses, and optionally extracts one top-level
#' key. Returns `NULL` if nothing parseable is found. With ellmer structured
#' output this is rarely needed, but it is kept for custom prompts and
#' providers without structured-output support.
#'
#' @param s A character string (or `NULL`).
#' @param top_level_key Optional name of a top-level element to extract.
#' @return A list (unsimplified JSON), the extracted element, or `NULL`.
#' @export
#' @examples
#' messy <- 'Sure! ```json\n{"bullets": ["one", "two"]}\n``` Hope that helps.'
#' robust_json_parse(messy, top_level_key = "bullets")
#' robust_json_parse("no json here")  # NULL
robust_json_parse <- function(s, top_level_key = NULL) {
  if (is.null(s) || length(s) != 1 || is.na(s)) {
    return(NULL)
  }
  json_start <- regexpr("{", s, fixed = TRUE)
  json_end <- max(gregexpr("}", s, fixed = TRUE)[[1]])
  if (json_start < 0 || json_end < 0 || json_end < json_start) {
    return(NULL)
  }
  s_trimmed <- substr(s, json_start, json_end)
  parsed <- tryCatch(
    jsonlite::fromJSON(s_trimmed, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) {
    return(NULL)
  }
  if (!is.null(top_level_key) && top_level_key %in% names(parsed)) {
    return(parsed[[top_level_key]])
  }
  parsed
}

#' Generate random UUID-like identifiers
#'
#' Used for concept IDs (upstream uses `uuid.uuid4()`). Not cryptographically
#' meaningful; collision probability is negligible at LLooM scales.
#'
#' @param n Number of IDs.
#' @return Character vector of length `n`.
#' @noRd
new_id <- function(n = 1) {
  hex <- c(0:9, letters[1:6])
  one <- function() {
    chars <- sample(hex, 32, replace = TRUE)
    paste0(
      paste(chars[1:8], collapse = ""), "-",
      paste(chars[9:12], collapse = ""), "-",
      paste(chars[13:16], collapse = ""), "-",
      paste(chars[17:20], collapse = ""), "-",
      paste(chars[21:32], collapse = "")
    )
  }
  vapply(seq_len(n), function(i) one(), character(1))
}

#' Build the seeding phrase inserted into distill/synthesize prompts
#'
#' Mirrors the per-operator seeding phrases in upstream concept_induction.py.
#'
#' @param seed Optional seed term (string or `NULL`).
#' @param step One of "distill_filter", "distill_summarize", "synthesize".
#' @return A string (possibly empty).
#' @noRd
seeding_phrase <- function(seed, step) {
  if (step == "distill_filter") {
    if (is.null(seed)) "MOST IMPORTANT" else toupper(paste("related to", seed))
  } else if (step == "distill_summarize") {
    if (is.null(seed)) "" else toupper(paste("related to", seed))
  } else if (step == "synthesize") {
    if (is.null(seed)) "" else paste0("The patterns MUST BE RELATED TO ", toupper(seed), ".")
  } else {
    cli::cli_abort("Unknown step {.val {step}} for seeding phrase.")
  }
}
