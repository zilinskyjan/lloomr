# Cluster operator: embed texts, reduce with UMAP, cluster with HDBSCAN.
# Mirrors cluster() and cluster_helper() in upstream concept_induction.py.
#
# Algorithmic parity notes:
# - UMAP parameters match upstream exactly (n_neighbors = 15, n_components = 5,
#   min_dist = 0, metric = "cosine"), with n_neighbors/n_components clamped
#   for small inputs.
# - dbscan::hdbscan() uses excess-of-mass cluster selection; upstream's
#   hdbscan uses cluster_selection_method = "leaf". This typically yields
#   slightly larger, coarser clusters, which is acceptable here: clusters
#   only batch examples for concept synthesis.
# - Cluster labels follow the upstream convention: -1 = noise, clusters
#   numbered from 0. (dbscan natively uses 0 = noise, clusters from 1.)

#' Cluster texts by semantic similarity
#'
#' Embeds each text (typically the bullets from [distill_summarize()]),
#' reduces the embeddings to 5 dimensions with UMAP, and clusters with
#' HDBSCAN. Each cluster later becomes one batch of examples for concept
#' synthesis.
#'
#' @param df Data frame of texts (typically one row per bullet).
#' @param text_col,id_col Column names (strings) for text and document IDs.
#' @param embed_fn Function mapping a character vector to an embedding
#'   matrix (one row per text). Defaults to [ll_embed()] with `embed_model`.
#'   Supply your own to use a different provider.
#' @param embed_model Embedding model name passed to [ll_embed()] when
#'   `embed_fn` is not supplied. Default `"text-embedding-3-large"`
#'   (upstream default).
#' @param embeddings Optional precomputed embedding matrix (one row per row
#'   of `df` *after* empty-text filtering); skips the embedding call.
#' @param min_cluster_size Minimum HDBSCAN cluster size. Default `NULL` =
#'   `max(3, floor(n/10))` (upstream heuristic).
#' @param randomize If `TRUE`, skip embeddings entirely and assign shuffled
#'   texts to pseudo-clusters of `batch_size` (upstream's `randomize` mode,
#'   an ablation/fallback).
#' @param batch_size Pseudo-cluster size for `randomize` mode. Default 20.
#' @param seed Optional integer; if supplied, clustering is reproducible
#'   (sets the RNG seed and runs UMAP single-threaded).
#' @return A tibble with columns `id_col`, `text_col`, and `cluster_id`
#'   (integer; -1 = noise/outliers, clusters numbered from 0), sorted by
#'   `cluster_id`. The embedding matrix is attached as attribute
#'   `"embeddings"` (`NULL` in randomize mode).
#' @export
#' @examples
#' df <- data.frame(id = 1:6, text = paste("bullet point", 1:6))
#'
#' # randomize mode needs no embeddings (upstream's ablation/fallback)
#' cluster_texts(df, "text", "id", randomize = TRUE, batch_size = 3, seed = 1)
#'
#' \dontrun{
#' # Real clustering: embeds via the OpenAI API, then UMAP + HDBSCAN
#' cluster_texts(bullets, "text", "post_id", seed = 42)
#' }
cluster_texts <- function(df,
                          text_col,
                          id_col,
                          embed_fn = NULL,
                          embed_model = "text-embedding-3-large",
                          embeddings = NULL,
                          min_cluster_size = NULL,
                          randomize = FALSE,
                          batch_size = 20,
                          seed = NULL) {
  df <- filter_empty_rows(df, text_col)
  n <- nrow(df)
  stopifnot(n > 0)
  if (!is.null(seed)) set.seed(seed)

  ids <- as.character(df[[id_col]])
  texts <- df[[text_col]]

  if (randomize) {
    # Shuffle and assign consecutive batches as pseudo-clusters
    shuffled <- sample.int(n)
    cluster_ids <- integer(n)
    cluster_ids[shuffled] <- (seq_len(n) - 1L) %/% batch_size
    out <- tibble::tibble(
      !!id_col := ids,
      !!text_col := texts,
      cluster_id = cluster_ids
    )
    out <- out[order(out$cluster_id), , drop = FALSE]
    attr(out, "embeddings") <- NULL
    return(out)
  }

  if (is.null(min_cluster_size)) {
    min_cluster_size <- max(3, floor(n / 10))
  }
  min_cluster_size <- max(2, as.integer(min_cluster_size))

  if (n < 2 * min_cluster_size) {
    cli::cli_warn(
      "Only {n} texts for min_cluster_size = {min_cluster_size}; assigning all to one cluster."
    )
    out <- tibble::tibble(
      !!id_col := ids,
      !!text_col := texts,
      cluster_id = 0L
    )
    attr(out, "embeddings") <- embeddings
    return(out)
  }

  # Embed
  if (is.null(embeddings)) {
    if (is.null(embed_fn)) {
      embed_fn <- function(t) ll_embed(t, model = embed_model)
    }
    embeddings <- embed_fn(texts)
  }
  stopifnot(is.matrix(embeddings), nrow(embeddings) == n)

  # UMAP reduction (upstream: n_neighbors=15, n_components=5, min_dist=0, cosine)
  n_neighbors <- min(15, n - 1)
  n_components <- min(5, n - 2)
  umap_embeddings <- uwot::umap(
    embeddings,
    n_neighbors = n_neighbors,
    n_components = n_components,
    min_dist = 0,
    metric = "cosine",
    n_sgd_threads = if (is.null(seed)) "auto" else 1
  )

  # HDBSCAN (dbscan: 0 = noise, clusters from 1 -> upstream: -1 = noise, from 0)
  hdb <- dbscan::hdbscan(umap_embeddings, minPts = min_cluster_size)
  cluster_ids <- as.integer(hdb$cluster) - 1L

  out <- tibble::tibble(
    !!id_col := ids,
    !!text_col := texts,
    cluster_id = cluster_ids
  )
  out <- out[order(out$cluster_id), , drop = FALSE]
  attr(out, "embeddings") <- embeddings[order(cluster_ids), , drop = FALSE]
  out
}
