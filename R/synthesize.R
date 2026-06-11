# Synthesize operator: LLM proposes named concepts from clustered examples.
# Mirrors synthesize() in upstream concept_induction.py.
#
# Deviations from upstream (deliberate):
# - When batch_size splits clusters into several prompts, each prompt keeps
#   its own cluster label (upstream zips results against cluster ids and
#   misattributes batches).
# - dedupe removes duplicate concepts from both the concept table and the
#   assignment table (upstream dedupes only the assignment df, leaving
#   duplicates in the concepts dict).

#' Synthesize concepts from clustered examples
#'
#' For each cluster of texts (from [cluster_texts()]), asks the LLM to
#' propose high-level patterns: a 2-4 word name, a 1-sentence inclusion
#' criterion ("prompt"), and the IDs of 1-2 best-exemplifying examples.
#' This is the step that turns groups of bullets into candidate concepts.
#'
#' @param cluster_df Data frame with text, ID, and cluster columns
#'   (the output of [cluster_texts()]).
#' @param text_col,id_col Column names (strings) for text and document IDs.
#' @param chat An ellmer chat object (a capable model is recommended here;
#'   upstream defaults to gpt-4o for this step).
#' @param cluster_id_col Name of the cluster column. Default `"cluster_id"`.
#' @param n_concepts Number of concepts to request per cluster. Default
#'   `NULL` = `ceiling(cluster_size / 3)` (upstream heuristic).
#' @param batch_size Optional maximum examples per prompt; clusters larger
#'   than this are split across several prompts. Default `NULL` (no split).
#' @param pattern_phrase Noun used in the prompt for what to find. Default
#'   `"unifying pattern"` (upstream's session pipeline uses `"unique topic"`).
#' @param dedupe Drop concepts with identical name + prompt. Default `TRUE`.
#' @param seed Optional seed term steering synthesis; recorded in the
#'   concepts' `seed` field.
#' @param prompt_template Optional custom template (validated).
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A list with:
#'   * `concepts` — a [new_concepts()] tibble (one row per concept,
#'     `active = FALSE`);
#'   * `assignments` — a tibble linking concepts to their exemplar
#'     documents: `id_col`, `text_col`, `concept_id`, `concept_name`,
#'     `concept_prompt`, `seed` (only exemplar IDs actually present in the
#'     concept's cluster are kept, as upstream).
#'   Token/cost usage is attached to the list as attribute `"usage"`.
#' @export
#' @examples
#' \dontrun{
#' chat <- ellmer::chat_openai(model = "gpt-5.2", echo = "none")
#' clusters <- cluster_texts(bullets, "text", "post_id")
#' synth <- synthesize_concepts(clusters, "text", "post_id", chat)
#' synth$concepts
#' }
synthesize_concepts <- function(cluster_df,
                                text_col,
                                id_col,
                                chat,
                                cluster_id_col = "cluster_id",
                                n_concepts = NULL,
                                batch_size = NULL,
                                pattern_phrase = "unifying pattern",
                                dedupe = TRUE,
                                seed = NULL,
                                prompt_template = NULL,
                                max_active = 10,
                                rpm = 500) {
  if (is.null(prompt_template)) {
    prompt_template <- lloom_prompt("synthesize")
  } else {
    validate_prompt("synthesize", prompt_template)
  }
  cluster_df <- filter_empty_rows(cluster_df, text_col)
  stopifnot(nrow(cluster_df) > 0, cluster_id_col %in% names(cluster_df))

  n_concepts_phrase <- function(cluster_size) {
    n <- if (is.null(n_concepts)) ceiling(cluster_size / 3) else n_concepts
    if (n > 1) paste("up to", n, paste0(pattern_phrase, "s")) else paste(n, pattern_phrase)
  }

  examples_block <- function(batch) {
    ex_list <- purrr::map2(
      as.character(batch[[id_col]]), batch[[text_col]],
      function(id, text) list(example_id = id, example = text)
    )
    as.character(jsonlite::toJSON(ex_list, auto_unbox = TRUE))
  }

  # One prompt per cluster (or per batch within a cluster), each tagged
  # with its cluster's id and member ids
  cluster_ids <- unique(cluster_df[[cluster_id_col]])
  prompt_meta <- purrr::list_flatten(purrr::map(cluster_ids, function(cl) {
    cur <- cluster_df[cluster_df[[cluster_id_col]] == cl, , drop = FALSE]
    starts <- if (is.null(batch_size)) 1 else seq(1, nrow(cur), by = batch_size)
    purrr::map(starts, function(s) {
      batch <- if (is.null(batch_size)) cur else cur[s:min(s + batch_size - 1, nrow(cur)), , drop = FALSE]
      list(
        cluster_id = cl,
        batch = batch,
        prompt = render_prompt(prompt_template, list(
          examples = examples_block(batch),
          n_concepts_phrase = n_concepts_phrase(nrow(cur)),
          seeding_phrase = seeding_phrase(seed, "synthesize")
        ))
      )
    })
  }))

  prompts <- vapply(prompt_meta, function(m) m$prompt, character(1))
  results <- ll_query(chat, prompts, lloom_type("synthesize"),
                      max_active = max_active, rpm = rpm)

  # Collect patterns across prompts, keeping each prompt's cluster context
  seed_label <- if (is.null(seed)) NA_character_ else seed
  all_concepts <- list()
  all_assignments <- list()
  for (i in seq_along(results)) {
    res <- results[[i]]
    if (is.null(res) || length(res$patterns) == 0) next
    meta <- prompt_meta[[i]]
    batch_ids <- as.character(meta$batch[[id_col]])

    for (pat in res$patterns) {
      ex_ids <- unique(as.character(unlist(pat$example_ids)))
      concept <- new_concepts(
        name = as.character(pat$name),
        prompt = as.character(pat$prompt),
        example_ids = list(ex_ids),
        seed = seed_label
      )
      all_concepts[[length(all_concepts) + 1]] <- concept

      # Keep only exemplar IDs actually present in this prompt's batch
      valid_ids <- intersect(ex_ids, batch_ids)
      if (length(valid_ids) > 0) {
        pos <- match(valid_ids, batch_ids)
        all_assignments[[length(all_assignments) + 1]] <- tibble::tibble(
          !!id_col := valid_ids,
          !!text_col := meta$batch[[text_col]][pos],
          concept_id = concept$id,
          concept_name = concept$name,
          concept_prompt = concept$prompt,
          seed = seed_label
        )
      }
    }
  }

  concepts <- dplyr::bind_rows(all_concepts)
  assignments <- dplyr::bind_rows(all_assignments)

  if (nrow(concepts) == 0) {
    cli::cli_warn("Synthesis produced no concepts.")
    out <- list(concepts = concepts, assignments = assignments)
    attr(out, "usage") <- attr(results, "usage")
    return(out)
  }
  class(concepts) <- c("lloom_concepts", class(tibble::tibble()))

  if (dedupe) {
    name_prompt <- paste0(concepts$name, ": ", concepts$prompt)
    keep <- !duplicated(name_prompt)
    dropped_ids <- concepts$id[!keep]
    concepts <- concepts[keep, , drop = FALSE]
    if (nrow(assignments) > 0) {
      assignments <- assignments[!assignments$concept_id %in% dropped_ids, , drop = FALSE]
    }
  }

  out <- list(concepts = concepts, assignments = assignments)
  attr(out, "usage") <- attr(results, "usage")
  out
}
