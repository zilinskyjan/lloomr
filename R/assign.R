# Single-topic assignment (lloomr extension, not in upstream text_lloom).
#
# LLooM scoring is multi-label by design: every document is rated against
# every concept independently, so a document can match several concepts or
# none. When a single-membership partition is wanted instead — each
# document slotted into exactly one topic from a fixed, user-approved set —
# use one of:
#   * assign_topics()  — forced-choice LLM classification; the topic label
#     is constrained to the fixed set at the schema level.
#   * slot_by_score()  — deterministic argmax over an existing score_df;
#     no additional LLM calls.

#' Assign each document to exactly one topic
#'
#' Forced-choice classification of documents into a fixed topic set
#' (typically the concepts kept after [review_concepts()] /
#' [refine_concepts()], possibly edited by the user). Unlike
#' [score_concepts()], which rates every (document, concept) pair
#' independently (multi-label), this returns exactly one topic per
#' document. The topic label is constrained to the provided set via the
#' structured-output schema, so the model cannot invent labels.
#'
#' This is an lloomr extension; the upstream Python package has no
#' single-label operator.
#'
#' @param df Data frame of documents.
#' @param text_col,id_col Column names (strings) for document text and IDs.
#' @param topics The fixed topic set: either a concept tibble (names and
#'   prompts are shown to the model) or a character vector of topic names.
#' @param chat An ellmer chat object.
#' @param allow_other If `TRUE` (default), adds an `other_label` option for
#'   documents fitting none of the topics; with `FALSE` the model must
#'   force every document into one of the topics.
#' @param other_label Label used for non-fitting documents. Default
#'   `"Other"`.
#' @param batch_size Documents per LLM call. Default 5.
#' @param max_active,rpm Concurrency controls passed to [ll_query()].
#' @return A tibble with one row per document: `id_col`, `text`, `topic`,
#'   `rationale`. Documents missing from LLM responses get `topic = NA`
#'   (with a warning). Token/cost usage is attached as attribute
#'   `"usage"`.
#' @export
#' @examples
#' \dontrun{
#' topics <- new_concepts(
#'   name = c("Vaccine Promotion", "Media Distrust"),
#'   prompt = c("Promotes vaccination?", "Expresses distrust of media?")
#' )
#' assignments <- assign_topics(df, "text", "post_id", topics, chat)
#' table(assignments$topic)
#' }
assign_topics <- function(df,
                          text_col,
                          id_col,
                          topics,
                          chat,
                          allow_other = TRUE,
                          other_label = "Other",
                          batch_size = 5,
                          max_active = 10,
                          rpm = 500) {
  # Accept a concept tibble or a bare character vector of names
  if (is.data.frame(topics)) {
    validate_concepts(topics)
    topic_names <- topics$name
    topics_text <- paste0("- ", topics$name, ": ", topics$prompt, collapse = "\n")
  } else {
    stopifnot(is.character(topics), length(topics) > 0)
    topic_names <- topics
    topics_text <- paste0("- ", topics, collapse = "\n")
  }
  stopifnot(!anyDuplicated(topic_names))

  df <- filter_empty_rows(df, text_col)
  stopifnot(nrow(df) > 0)
  doc_ids <- as.character(df[[id_col]])
  stopifnot(!anyDuplicated(doc_ids))

  if (allow_other) {
    other_clause <- paste0(
      " If an example does not fit ANY of the topics, assign \"",
      other_label, "\"."
    )
    valid_labels <- c(topic_names, other_label)
  } else {
    other_clause <- ""
    valid_labels <- topic_names
  }

  # Response schema: the topic field is an enum over the fixed label set
  type <- ellmer::type_object(
    assignments = ellmer::type_array(
      ellmer::type_object(
        example_id = ellmer::type_string(),
        rationale = ellmer::type_string("1-sentence rationale"),
        topic = ellmer::type_enum(valid_labels, "The single best-fitting topic")
      )
    )
  )

  batch_starts <- seq(1, length(doc_ids), by = batch_size)
  prompt_meta <- purrr::map(batch_starts, function(s) {
    idx <- s:min(s + batch_size - 1, length(doc_ids))
    list(
      batch_ids = doc_ids[idx],
      prompt = render_prompt(lloom_prompt("assign_topic"), list(
        examples_json = examples_to_json(df[idx, , drop = FALSE], id_col, text_col),
        topics = topics_text,
        other_clause = other_clause
      ))
    )
  })

  prompts <- vapply(prompt_meta, function(m) m$prompt, character(1))
  results <- ll_query(chat, prompts, type, max_active = max_active, rpm = rpm)

  parsed <- purrr::map2(results, prompt_meta, function(res, meta) {
    if (is.null(res) || length(res$assignments) == 0) {
      return(NULL)
    }
    rows <- purrr::map(res$assignments, function(a) {
      ex_id <- as.character(a$example_id %||% "")
      topic <- as.character(a$topic %||% "")
      if (!ex_id %in% meta$batch_ids || !topic %in% valid_labels) {
        return(NULL)
      }
      tibble::tibble(
        !!id_col := ex_id,
        topic = topic,
        rationale = as.character(a$rationale %||% "")
      )
    })
    dplyr::bind_rows(purrr::compact(rows))
  })
  assigned <- dplyr::bind_rows(purrr::compact(parsed))

  out <- tibble::tibble(!!id_col := doc_ids, text = df[[text_col]])
  if (nrow(assigned) > 0) {
    assigned <- assigned[!duplicated(assigned[[id_col]]), , drop = FALSE]
    out <- dplyr::left_join(out, assigned, by = id_col)
  } else {
    out$topic <- NA_character_
    out$rationale <- NA_character_
  }

  n_missing <- sum(is.na(out$topic))
  if (n_missing > 0) {
    cli::cli_warn("{n_missing} document{?s} missing from LLM responses; topic set to NA.")
  }

  # Defensive: exactly one row per document
  stopifnot(nrow(out) == length(doc_ids), !anyDuplicated(out[[id_col]]))

  attr(out, "usage") <- attr(results, "usage")
  out
}

#' Slot each document into one topic from existing scores
#'
#' Deterministic single-label assignment derived from a multi-label
#' [score_concepts()] result: each document gets the concept on which it
#' scored highest. Costs no LLM calls. Ties and non-matches are handled
#' explicitly:
#' * if the document's best score is below `threshold`, it is labeled
#'   `other_label`;
#' * if several concepts tie for the best score, the first in `score_df`
#'   order wins and `tie = TRUE` flags the ambiguity.
#'
#' @param score_df Output of [score_concepts()].
#' @param id_col Column name for document IDs.
#' @param threshold Minimum best score required to assign a topic; below it
#'   the document is labeled `other_label`. Default 0.75 ("agree" or
#'   stronger).
#' @param other_label Label for documents matching no concept. Default
#'   `"Other"`.
#' @return A tibble with one row per document: `id_col`, `text`, `topic`,
#'   `topic_score` (the winning score), `tie` (logical).
#' @export
#' @examples
#' score_df <- data.frame(
#'   doc_id = rep(c("1", "2", "3"), each = 2),
#'   text = rep(c("clear economy doc", "ambiguous doc", "off-topic doc"), each = 2),
#'   concept_name = rep(c("Economy", "Media"), 3),
#'   score = c(1, 0.25,   1, 1,   0.5, 0.25)
#' )
#' # Doc 1: Economy wins; doc 2: tie (flagged); doc 3: below threshold -> Other
#' slot_by_score(score_df, "doc_id")
slot_by_score <- function(score_df,
                          id_col,
                          threshold = 0.75,
                          other_label = "Other") {
  stopifnot(
    all(c(id_col, "text", "concept_name", "score") %in% names(score_df)),
    nrow(score_df) > 0
  )

  out <- dplyr::bind_rows(lapply(split(score_df, score_df[[id_col]]), function(d) {
    best <- max(d$score)
    winners <- d$concept_name[d$score == best]
    tibble::tibble(
      !!id_col := d[[id_col]][1],
      text = d$text[1],
      topic = if (best >= threshold) winners[1] else other_label,
      topic_score = best,
      tie = best >= threshold && length(winners) > 1
    )
  }))

  # Defensive: exactly one row per document
  n_docs <- length(unique(score_df[[id_col]]))
  stopifnot(nrow(out) == n_docs, !anyDuplicated(out[[id_col]]))
  tibble::as_tibble(out)
}
