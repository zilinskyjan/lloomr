# Review operators: LLM-driven quality control of the concept set.
# Mirrors review(), review_remove(), review_merge(), review_select() in
# upstream concept_induction.py (+ select_auto() in workbench.py).
#
# Deviations from upstream (deliberate):
# - review_merge() requires both originals of a merge pair to exist and
#   skips pairs that reuse an already-merged concept (upstream's duplicate
#   guard was a no-op `continue` in an inner loop).
# - When updating assignments after a merge, the concept_id is updated to
#   the merged concept's id (upstream overwrote the id column with a
#   "name: prompt" string).

#' Remove low-quality concepts
#'
#' Asks the LLM which concepts to drop: without a `seed`, those too narrow
#' or too broad; with a `seed`, those unrelated to the seed topic.
#'
#' @param concepts A concept tibble (see [new_concepts()]).
#' @param chat An ellmer chat object.
#' @param seed Optional seed term; switches to the seeded variant prompt.
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A list: `concepts` (kept rows) and `removed` (character vector
#'   of removed names). If the query fails, all concepts are kept.
#' @export
#' @examples
#' \dontrun{
#' res <- review_remove(concepts, chat)
#' res$removed
#' }
review_remove <- function(concepts, chat, seed = NULL, max_active = 10, rpm = 500) {
  validate_concepts(concepts)
  step <- if (is.null(seed)) "review_remove" else "review_remove_seed"
  args <- list(concepts = concepts_to_text(concepts))
  if (!is.null(seed)) args$seed <- seed

  prompt <- render_prompt(lloom_prompt(step), args)
  res <- ll_query(chat, prompt, lloom_type(step), max_active = max_active, rpm = rpm)[[1]]

  to_remove <- intersect(unique(as.character(unlist(res$remove))), concepts$name)
  list(
    concepts = concepts[!concepts$name %in% to_remove, , drop = FALSE],
    removed = to_remove
  )
}

#' Merge overlapping concepts
#'
#' Asks the LLM for pairs of similar/overlapping concepts and replaces each
#' pair with a newly named merged concept (with the union of the originals'
#' exemplar IDs). Only pairs whose two originals both exist (and were not
#' already consumed by an earlier merge) are applied.
#'
#' @inheritParams review_remove
#' @return A list: `concepts` (with merged rows replacing originals) and
#'   `merged` (tibble with columns `original_1`, `original_2`, `merged_name`,
#'   `merged_id`; zero rows if nothing merged).
#' @export
#' @examples
#' \dontrun{
#' res <- review_merge(concepts, chat)
#' res$merged  # which pairs were combined, and into what
#' }
review_merge <- function(concepts, chat, max_active = 10, rpm = 500) {
  validate_concepts(concepts)
  prompt <- render_prompt(
    lloom_prompt("review_merge"),
    list(concepts = concepts_to_text(concepts))
  )
  res <- ll_query(chat, prompt, lloom_type("review_merge"),
                  max_active = max_active, rpm = rpm)[[1]]

  merged_log <- list()
  consumed <- character(0)

  for (m in res$merge) {
    originals <- as.character(unlist(m$original_themes))
    if (length(originals) != 2) next                      # only pairs
    if (!all(originals %in% concepts$name)) next          # both must exist
    if (any(originals %in% consumed)) next                # not already merged

    rows <- match(originals, concepts$name)
    merged_concept <- new_concepts(
      name = as.character(m$merged_theme_name),
      prompt = as.character(m$merged_theme_prompt),
      example_ids = list(unique(unlist(concepts$example_ids[rows])))
    )
    consumed <- c(consumed, originals)
    concepts <- concepts[-rows, , drop = FALSE]
    concepts <- dplyr::bind_rows(concepts, merged_concept)
    class(concepts) <- c("lloom_concepts", class(tibble::tibble()))

    merged_log[[length(merged_log) + 1]] <- tibble::tibble(
      original_1 = originals[1],
      original_2 = originals[2],
      merged_name = merged_concept$name,
      merged_id = merged_concept$id
    )
  }

  list(concepts = concepts, merged = dplyr::bind_rows(merged_log))
}

#' Select the best concepts (sets `active`)
#'
#' Asks the LLM to pick at most `max_concepts` high-quality, non-overlapping
#' concepts, and marks those rows `active = TRUE` (everything else
#' `FALSE`). If the LLM selects nothing usable, a random sample is
#' activated instead, with a warning (mirroring upstream's fallback).
#'
#' @inheritParams review_remove
#' @param max_concepts Maximum number of concepts to activate.
#' @return The concept tibble with `active` updated.
#' @export
#' @examples
#' \dontrun{
#' concepts <- review_select(concepts, max_concepts = 5, chat)
#' concepts[concepts$active, c("name", "prompt")]
#' }
review_select <- function(concepts, max_concepts, chat, max_active = 10, rpm = 500) {
  validate_concepts(concepts)
  prompt <- render_prompt(
    lloom_prompt("review_select"),
    list(concepts = concepts_to_text(concepts), max_concepts = max_concepts)
  )
  res <- ll_query(chat, prompt, lloom_type("review_select"),
                  max_active = max_active, rpm = rpm)[[1]]

  selected_names <- intersect(unique(as.character(unlist(res$selected))), concepts$name)
  selected_ids <- concepts$id[concepts$name %in% selected_names]
  if (length(selected_ids) > max_concepts) {
    selected_ids <- selected_ids[seq_len(max_concepts)]
  }
  if (length(selected_ids) == 0) {
    cli::cli_warn("Concept selection failed; activating a random sample of {max_concepts}.")
    selected_ids <- sample(concepts$id, min(max_concepts, nrow(concepts)))
  }

  concepts$active <- concepts$id %in% selected_ids
  concepts
}

#' Review a concept set: remove, merge, and optionally select
#'
#' The full auto-review pass run after synthesis (upstream `review()`):
#' removes too-narrow/too-broad concepts (or, with `seed`, off-topic ones),
#' merges overlapping pairs, and — if `max_concepts` is given — activates
#' the best subset. If an `assignments` table from [synthesize_concepts()]
#' is supplied, it is kept in sync (removed concepts dropped, merged
#' concepts relabeled).
#'
#' @inheritParams review_remove
#' @param assignments Optional assignments tibble from
#'   [synthesize_concepts()] to keep in sync.
#' @param max_concepts Optional; if supplied, runs [review_select()] too.
#' @return A list: `concepts`, `assignments` (or `NULL`), `removed`
#'   (character names), `merged` (tibble).
#' @export
#' @examples
#' \dontrun{
#' synth <- synthesize_concepts(clusters, "text", "post_id", chat)
#' reviewed <- review_concepts(synth$concepts, chat,
#'                             assignments = synth$assignments,
#'                             max_concepts = 8)
#' reviewed$concepts
#' }
review_concepts <- function(concepts,
                            chat,
                            assignments = NULL,
                            seed = NULL,
                            max_concepts = NULL,
                            max_active = 10,
                            rpm = 500) {
  rem <- review_remove(concepts, chat, seed = seed, max_active = max_active, rpm = rpm)
  mrg <- review_merge(rem$concepts, chat, max_active = max_active, rpm = rpm)
  concepts_out <- mrg$concepts

  if (!is.null(max_concepts) && nrow(concepts_out) > 0) {
    concepts_out <- review_select(concepts_out, max_concepts, chat,
                                  max_active = max_active, rpm = rpm)
  }

  if (!is.null(assignments) && nrow(assignments) > 0) {
    # Drop assignments of removed concepts; relabel merged ones
    assignments <- assignments[!assignments$concept_name %in% rem$removed, , drop = FALSE]
    if (nrow(mrg$merged) > 0) {
      for (i in seq_len(nrow(mrg$merged))) {
        hit <- assignments$concept_name %in%
          c(mrg$merged$original_1[i], mrg$merged$original_2[i])
        assignments$concept_id[hit] <- mrg$merged$merged_id[i]
        assignments$concept_name[hit] <- mrg$merged$merged_name[i]
        assignments$concept_prompt[hit] <-
          concepts_out$prompt[match(mrg$merged$merged_id[i], concepts_out$id)]
      }
    }
    # Keep only assignments whose concept survived review
    assignments <- assignments[assignments$concept_id %in% concepts_out$id, , drop = FALSE]
  }

  list(
    concepts = concepts_out,
    assignments = assignments,
    removed = rem$removed,
    merged = mrg$merged
  )
}
