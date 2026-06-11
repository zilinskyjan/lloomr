# Refine and loop: data-driven concept pruning and coverage iteration.
# Mirrors refine(), get_not_covered(), get_covered_by_generic(), and loop()
# in upstream concept_induction.py.

#' Refine concepts by match prevalence
#'
#' Data-driven pruning after scoring: drops concepts that matched too many
#' documents (generic) or too few (rare).
#'
#' @param score_df Output of [score_concepts()].
#' @param concepts Concept tibble to refine.
#' @param threshold Minimum score counting as a match. Default 1 (upstream:
#'   only "strongly agree").
#' @param generic_threshold Concepts matching at least this fraction of
#'   documents are dropped as generic. Default 0.75 (upstream).
#' @param rare_threshold Concepts matching less than this fraction are
#'   dropped as rare. Default 0.05 (upstream).
#' @return A list: `concepts` (kept rows), `generic` and `rare` (character
#'   vectors of dropped concept names).
#' @export
#' @examples
#' concepts <- new_concepts(c("Everything", "Niche"), c("Is text?", "About X?"))
#' # "Everything" matches all 10 docs (generic); "Niche" matches none (rare)
#' score_df <- data.frame(
#'   doc_id = rep(1:10, 2),
#'   concept_id = rep(concepts$id, each = 10),
#'   concept_name = rep(concepts$name, each = 10),
#'   score = rep(c(1, 0), each = 10)
#' )
#' refine_concepts(score_df, concepts)
refine_concepts <- function(score_df,
                            concepts,
                            threshold = 1,
                            generic_threshold = 0.75,
                            rare_threshold = 0.05) {
  validate_concepts(concepts)
  scored_ids <- intersect(concepts$id, unique(score_df$concept_id))

  pos_frac <- vapply(scored_ids, function(c_id) {
    c_scores <- score_df$score[score_df$concept_id == c_id]
    mean(c_scores >= threshold)
  }, numeric(1))

  generic_ids <- scored_ids[pos_frac >= generic_threshold]
  rare_ids <- scored_ids[pos_frac < rare_threshold]
  generic <- concepts$name[concepts$id %in% generic_ids]
  rare <- concepts$name[concepts$id %in% rare_ids]

  if (length(generic) > 0) {
    cli::cli_inform("Dropping {length(generic)} generic concept{?s}: {.val {generic}}")
  }
  if (length(rare) > 0) {
    cli::cli_inform("Dropping {length(rare)} rare concept{?s}: {.val {rare}}")
  }

  list(
    concepts = concepts[!concepts$id %in% c(generic_ids, rare_ids), , drop = FALSE],
    generic = generic,
    rare = rare
  )
}

#' Document IDs not matching any concept
#' @noRd
get_not_covered <- function(score_df, id_col, threshold = 1) {
  matches <- tapply(score_df$score >= threshold, score_df[[id_col]], sum)
  names(matches)[matches == 0]
}

#' Document IDs matching only generic concepts
#' @noRd
get_covered_by_generic <- function(score_df, id_col, threshold = 1,
                                   generic_threshold = 0.5) {
  pos_frac <- tapply(score_df$score >= threshold, score_df$concept_id, mean)
  generic_ids <- names(pos_frac)[pos_frac >= generic_threshold]
  if (length(generic_ids) == 0) {
    return(character(0))
  }
  rest <- score_df[!score_df$concept_id %in% generic_ids, , drop = FALSE]
  get_not_covered(rest, id_col, threshold)
}

#' Find documents needing another concept-induction iteration
#'
#' Implements the LLooM loop operator: identifies documents that are either
#' not covered by any concept or covered only by generic concepts (those
#' matching at least half of all documents), and returns them for another
#' round of concept generation.
#'
#' @param score_df Output of [score_concepts()].
#' @param text_col,id_col Column names for document text and IDs (`text_col`
#'   should name the text column in `score_df`, i.e. `"text"`).
#' @param threshold Minimum score counting as a match. Default 1.
#' @param generic_threshold Fraction of documents a concept must match to
#'   count as generic for coverage purposes. Default 0.5 (upstream).
#' @return A tibble of documents (`id_col`, `text_col`) to feed into the
#'   next iteration, or `NULL` if iteration should stop (every document
#'   would be included again, or none would).
#' @export
#' @examples
#' # Doc 1 matches the concept; docs 2-3 are uncovered -> returned for
#' # another round
#' score_df <- data.frame(
#'   doc_id = c("1", "2", "3"),
#'   text = c("covered doc", "uncovered doc", "another uncovered"),
#'   concept_id = "c1", concept_name = "Concept",
#'   score = c(1, 0, 0)
#' )
#' loop_docs(score_df, "text", "doc_id")
loop_docs <- function(score_df,
                      text_col = "text",
                      id_col,
                      threshold = 1,
                      generic_threshold = 0.5) {
  ids_to_include <- union(
    get_not_covered(score_df, id_col, threshold),
    get_covered_by_generic(score_df, id_col, threshold, generic_threshold)
  )

  docs <- score_df[score_df[[id_col]] %in% ids_to_include, c(id_col, text_col), drop = FALSE]
  docs <- docs[!duplicated(docs[[id_col]]), , drop = FALSE]

  n_initial <- length(unique(score_df[[id_col]]))
  if (nrow(docs) == 0 || nrow(docs) == n_initial) {
    return(NULL)
  }
  tibble::as_tibble(docs)
}
