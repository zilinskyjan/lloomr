# Concept proximity (lloomr extension; no upstream counterpart).
#
# Two complementary notions of how close concepts are:
# - "embedding": semantic similarity of the concepts themselves (their
#   name + inclusion-criterion text is embedded; cosine similarity).
# - "scores": empirical similarity in this corpus (correlation of the
#   concepts' score vectors across documents — concepts are close if
#   they tend to match the same documents).
# Divergence between the two is informative: semantically distinct
# concepts that co-fire reveal corpus structure, near-synonymous
# concepts that fire on different documents suggest the prompts are
# doing real work.

#' Pairwise similarity between concepts
#'
#' Computes a symmetric concept-by-concept similarity matrix, either from
#' embeddings of the concept definitions (`method = "embedding"`: cosine
#' similarity of the embedded `"name: prompt"` texts) or from scoring
#' results (`method = "scores"`: Pearson correlation of the concepts'
#' score vectors across documents).
#'
#' @param concepts A concept tibble (see [new_concepts()]).
#' @param method `"embedding"` (semantic similarity of the concept
#'   definitions) or `"scores"` (empirical co-matching in a scored
#'   corpus).
#' @param score_df Required for `method = "scores"`: output of
#'   [score_concepts()] / [lloom_results()].
#' @param id_col Required for `method = "scores"`: the document ID column
#'   in `score_df`.
#' @param embed_fn Embedding function for `method = "embedding"`
#'   (character vector in, matrix out). Defaults to [ll_embed()] with
#'   `embed_model`.
#' @param embed_model Embedding model for the default `embed_fn`.
#' @return A symmetric numeric matrix with concept names as dimnames.
#'   Diagonal is 1.
#' @export
#' @examples
#' \dontrun{
#' cc <- sess$concepts[sess$concepts$active, ]
#' concept_similarity(cc)                          # semantic
#' concept_similarity(cc, method = "scores",       # empirical
#'                    score_df = lloom_results(sess), id_col = "doc_id")
#' }
concept_similarity <- function(concepts,
                               method = c("embedding", "scores"),
                               score_df = NULL,
                               id_col = NULL,
                               embed_fn = NULL,
                               embed_model = "text-embedding-3-large") {
  validate_concepts(concepts)
  method <- match.arg(method)
  stopifnot(nrow(concepts) >= 2)

  if (method == "embedding") {
    if (is.null(embed_fn)) {
      embed_fn <- function(t) ll_embed(t, model = embed_model)
    }
    emb <- embed_fn(paste0(concepts$name, ": ", concepts$prompt))
    stopifnot(is.matrix(emb), nrow(emb) == nrow(concepts))
    emb_norm <- emb / sqrt(rowSums(emb^2))
    sim <- emb_norm %*% t(emb_norm)
  } else {
    if (is.null(score_df) || is.null(id_col)) {
      cli::cli_abort("{.code method = \"scores\"} requires {.arg score_df} and {.arg id_col}.")
    }
    present <- intersect(concepts$name, unique(score_df$concept_name))
    if (length(present) < nrow(concepts)) {
      cli::cli_warn("{nrow(concepts) - length(present)} concept{?s} not present in {.arg score_df}; dropped from the similarity matrix.")
      concepts <- concepts[concepts$name %in% present, , drop = FALSE]
      stopifnot(nrow(concepts) >= 2)
    }
    wide <- scores_wide(
      score_df[score_df$concept_name %in% concepts$name, , drop = FALSE],
      id_col,
      sanitize_names = FALSE
    )
    score_mat <- as.matrix(wide[, concepts$name, drop = FALSE])
    sim <- suppressWarnings(stats::cor(score_mat))
    sim[is.na(sim)] <- 0  # zero-variance concepts (all-0 or all-1 scores)
    diag(sim) <- 1
  }

  dimnames(sim) <- list(concepts$name, concepts$name)
  round(sim, 6)
}

#' Map concepts into 2D by their similarity
#'
#' Projects the concept similarity matrix into two dimensions (classical
#' multidimensional scaling of `1 - similarity`) and plots concepts as a
#' labeled scatter: nearby concepts are similar; when scores are
#' available, point size shows each concept's prevalence. The lloomr
#' answer to "how close are my concepts to each other?".
#'
#' @param sess A [lloom_session()] with concepts (and, for
#'   `method = "scores"` or prevalence sizing, scores).
#' @param method `"embedding"` (semantic; default) or `"scores"`
#'   (empirical co-matching). See [concept_similarity()].
#' @param threshold Minimum score counting as a match for prevalence
#'   sizing. Default 1.
#' @param embed_fn Optional embedding function override.
#' @return A ggplot object. The similarity matrix is attached as
#'   attribute `"similarity"`, and the MDS coordinates as attribute
#'   `"coords"`.
#' @export
#' @examples
#' \dontrun{
#' lloom_concept_map(sess)                      # semantic proximity
#' lloom_concept_map(sess, method = "scores")   # empirical proximity
#' }
lloom_concept_map <- function(sess,
                              method = c("embedding", "scores"),
                              threshold = 1,
                              embed_fn = NULL) {
  stopifnot(inherits(sess, "lloom_session"))
  method <- match.arg(method)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required for {.fn lloom_concept_map}.")
  }
  concepts <- sess$concepts[sess$concepts$active, , drop = FALSE]
  if (nrow(concepts) < 3) {
    cli::cli_abort("Need at least 3 active concepts to map (have {nrow(concepts)}).")
  }

  sim <- concept_similarity(
    concepts,
    method = method,
    score_df = sess$score_df,
    id_col = sess$id_col,
    embed_fn = embed_fn %||% if (method == "embedding") sess$embed_fn
  )

  coords <- stats::cmdscale(stats::as.dist(1 - sim), k = 2)
  plot_df <- tibble::tibble(
    concept = rownames(sim),
    dim1 = coords[, 1],
    dim2 = coords[, 2]
  )

  # Prevalence sizing when scores exist
  if (!is.null(sess$score_df)) {
    n_docs <- length(unique(sess$score_df[[sess$id_col]]))
    matches <- sess$score_df[sess$score_df$score >= threshold, , drop = FALSE]
    counts <- table(matches$concept_name)
    plot_df$prevalence <- as.numeric(counts[plot_df$concept]) / n_docs
    plot_df$prevalence[is.na(plot_df$prevalence)] <- 0
  } else {
    plot_df$prevalence <- NA_real_
  }

  method_lab <- if (method == "embedding") {
    "semantic similarity of concept definitions (embeddings)"
  } else {
    "correlation of concept scores across documents"
  }

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$dim1, y = .data$dim2))
  if (all(is.na(plot_df$prevalence))) {
    p <- p + ggplot2::geom_point(color = "#2c5f8a", alpha = 0.8, size = 3)
  } else {
    p <- p +
      ggplot2::geom_point(ggplot2::aes(size = .data$prevalence),
                          color = "#2c5f8a", alpha = 0.8) +
      ggplot2::scale_size_area(name = "Prevalence", max_size = 10)
  }
  p +
    ggplot2::geom_text(ggplot2::aes(label = .data$concept),
                       vjust = -1.1, size = 3.4) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.18)) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = 0.18)) +
    ggplot2::labs(
      title = "Concept proximity map",
      subtitle = paste0("Closer = more similar; ", method_lab),
      x = "Dimension 1", y = "Dimension 2"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = 14, face = "bold"),
      plot.title.position = "plot",
      panel.grid.minor = ggplot2::element_blank()
    ) -> p
  attr(p, "similarity") <- sim
  attr(p, "coords") <- coords
  p
}
