# Saving and reshaping results (lloomr addition; upstream's only
# persistence is pickling the whole workbench object).
#
# The score table is a plain tibble, so the simplest path is always
# available:   readr::write_csv(lloom_results(sess), "scores.csv")
# The helpers here cover the two steps beyond that: a wide document x
# concept matrix safe to join onto your main dataset, and a one-call
# writer for everything a finished analysis produces.

#' Reshape scores to one row per document (wide matrix)
#'
#' Pivots the long score table from [score_concepts()] /
#' [lloom_results()] into a document-by-concept matrix: one row per
#' document, one column per concept. This is the shape you want for
#' joining scores onto your main dataset for downstream analysis.
#'
#' Concept names are sanitized into valid, unique R column names by
#' default (e.g. `"China-related Disinformation"` becomes
#' `China.related.Disinformation`); the mapping is attached as attribute
#' `"concept_names"`. The output is guaranteed to have exactly one row
#' per document.
#'
#' @param score_df Output of [score_concepts()] / [lloom_results()].
#' @param id_col Column name for document IDs.
#' @param value_col Which column to spread. Default `"score"`.
#' @param sanitize_names Convert concept names to valid, unique R column
#'   names. Default `TRUE`.
#' @param include_text Keep the document `text` column. Default `FALSE`
#'   (typically you join back to the original data by ID instead).
#' @return A tibble with one row per document. The concept-name-to-column
#'   mapping is attached as attribute `"concept_names"` (a named character
#'   vector: names are original concept names, values are column names).
#' @export
#' @examples
#' score_df <- data.frame(
#'   doc_id = rep(c("1", "2"), each = 2),
#'   text = rep(c("first doc", "second doc"), each = 2),
#'   concept_name = rep(c("Media Distrust", "Vaccine Promotion"), 2),
#'   score = c(1, 0, 0.25, 1)
#' )
#' wide <- scores_wide(score_df, "doc_id")
#' wide
#' attr(wide, "concept_names")
#'
#' # Join back onto a main dataset, with the safety checks lloomr
#' # recommends for any merge:
#' main <- data.frame(doc_id = c("1", "2"), party = c("D", "R"))
#' stopifnot(nrow(wide) == nrow(main))
#' merged <- merge(main, wide, by = "doc_id")
#' stopifnot(nrow(merged) == nrow(main))
#' merged
scores_wide <- function(score_df,
                        id_col,
                        value_col = "score",
                        sanitize_names = TRUE,
                        include_text = FALSE) {
  stopifnot(all(c(id_col, "concept_name", value_col) %in% names(score_df)))
  if (anyDuplicated(score_df[, c(id_col, "concept_name")]) > 0) {
    cli::cli_abort("Duplicate (document, concept) pairs in {.arg score_df}; cannot pivot.")
  }

  id_cols <- c(id_col, if (include_text && "text" %in% names(score_df)) "text")
  concept_names <- unique(score_df$concept_name)
  out_names <- if (sanitize_names) make.unique(make.names(concept_names)) else concept_names

  wide <- tidyr::pivot_wider(
    score_df[, c(id_cols, "concept_name", value_col)],
    id_cols = dplyr::all_of(id_cols),
    names_from = "concept_name",
    values_from = dplyr::all_of(value_col)
  )
  names(wide)[match(concept_names, names(wide))] <- out_names

  # Defensive: exactly one row per document, nothing lost
  stopifnot(
    nrow(wide) == length(unique(score_df[[id_col]])),
    !anyDuplicated(wide[[id_col]])
  )
  attr(wide, "concept_names") <- stats::setNames(out_names, concept_names)
  wide
}

#' Write all session results to a folder
#'
#' One call to persist a finished analysis (after [lloom_score()]). Writes
#' to `dir`:
#'
#' * `scores_long.csv` — the full score table ([lloom_results()]): one row
#'   per (document, concept) pair with scores, rationales, highlights.
#' * `scores_wide.csv` — one row per document, one column per concept
#'   ([scores_wide()]), ready to join onto your main dataset.
#' * `concepts.csv` — the concept table (names, prompts, active flags).
#' * `concept_summary.csv` — the per-concept evidence table
#'   ([lloom_export()] with quotes collapsed into single cells).
#' * `session.rds` — the entire session object; restore with `readRDS()`
#'   (chat objects survive and keep working).
#'
#' For just the scores, you never need this function — the score table is
#' a plain data frame: `readr::write_csv(lloom_results(sess), "scores.csv")`.
#'
#' @param sess A [lloom_session()] after [lloom_score()].
#' @param dir Output directory (created if needed).
#' @param prefix Optional filename prefix (e.g. `"study1"` gives
#'   `study1_scores_long.csv`).
#' @return Invisibly, a named character vector of the written file paths.
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_score(lloom_gen(lloom_session(df, "text", "doc_id")))
#' lloom_write(sess, "results/")
#'
#' # Later, in a fresh R session:
#' sess <- readRDS("results/session.rds")
#' }
lloom_write <- function(sess, dir, prefix = NULL) {
  stopifnot(inherits(sess, "lloom_session"))
  if (is.null(sess$score_df)) {
    cli::cli_abort("No scores in session. Run {.fn lloom_score} first.")
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  fname <- function(name) {
    file.path(dir, paste0(if (!is.null(prefix)) paste0(prefix, "_"), name))
  }

  paths <- c(
    scores_long = fname("scores_long.csv"),
    scores_wide = fname("scores_wide.csv"),
    concepts = fname("concepts.csv"),
    concept_summary = fname("concept_summary.csv"),
    session = fname("session.rds")
  )

  utils::write.csv(sess$score_df, paths["scores_long"], row.names = FALSE)
  utils::write.csv(scores_wide(sess$score_df, sess$id_col), paths["scores_wide"],
                   row.names = FALSE)

  concepts_flat <- sess$concepts
  concepts_flat$example_ids <- vapply(
    concepts_flat$example_ids, paste, character(1), collapse = "; "
  )
  utils::write.csv(concepts_flat, paths["concepts"], row.names = FALSE)

  utils::write.csv(lloom_export(sess, collapse = TRUE), paths["concept_summary"],
                   row.names = FALSE)
  saveRDS(sess, paths["session"])

  cli::cli_inform("Wrote {length(paths)} files to {.path {dir}}: {.file {basename(paths)}}")
  invisible(paths)
}
