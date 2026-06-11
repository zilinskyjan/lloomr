# Deterministic tests on synthetic embeddings (no network) =================

# Three well-separated blobs (orthogonal directions, tight noise) so that
# UMAP + HDBSCAN must recover the structure.
make_blobs <- function(n_per = 20, dim = 20, seed = 42) {
  set.seed(seed)
  centers <- diag(10, dim)[1:3, ]  # 3 orthogonal centers
  emb <- do.call(rbind, lapply(1:3, function(b) {
    matrix(rnorm(n_per * dim, sd = 0.05), n_per, dim) +
      matrix(centers[b, ], n_per, dim, byrow = TRUE)
  }))
  list(
    df = data.frame(
      bullet_id = sprintf("b%02d", seq_len(3 * n_per)),
      text = sprintf("bullet %d", seq_len(3 * n_per)),
      blob = rep(1:3, each = n_per)
    ),
    embeddings = emb
  )
}

test_that("cluster_texts recovers well-separated blobs", {
  blobs <- make_blobs()
  out <- cluster_texts(
    blobs$df, "text", "bullet_id",
    embeddings = blobs$embeddings, seed = 1
  )

  expect_named(out, c("bullet_id", "text", "cluster_id"))
  expect_equal(nrow(out), 60)
  expect_true(is.integer(out$cluster_id))
  expect_gte(min(out$cluster_id), -1)            # -1 = noise convention
  expect_false(is.unsorted(out$cluster_id))      # sorted by cluster

  # Recovers 3 clusters with high purity
  merged <- merge(out, blobs$df[, c("bullet_id", "blob")], by = "bullet_id")
  assigned <- merged[merged$cluster_id != -1, ]
  expect_equal(length(unique(assigned$cluster_id)), 3)
  purity <- mean(vapply(split(assigned$blob, assigned$cluster_id), function(b) {
    max(table(b)) / length(b)
  }, numeric(1)))
  expect_gt(purity, 0.95)

  # Embeddings attribute is row-aligned with the (re-sorted) output
  emb_attr <- attr(out, "embeddings")
  expect_equal(dim(emb_attr), dim(blobs$embeddings))
  orig_pos <- match(out$bullet_id, blobs$df$bullet_id)
  expect_equal(emb_attr, blobs$embeddings[orig_pos, , drop = FALSE])
})

test_that("cluster_texts is reproducible with a seed", {
  blobs <- make_blobs()
  out1 <- cluster_texts(blobs$df, "text", "bullet_id",
                        embeddings = blobs$embeddings, seed = 7)
  out2 <- cluster_texts(blobs$df, "text", "bullet_id",
                        embeddings = blobs$embeddings, seed = 7)
  expect_equal(out1, out2, ignore_attr = TRUE)
})

test_that("cluster_texts uses embed_fn when no embeddings are given", {
  blobs <- make_blobs(n_per = 10)
  called_with <- NULL
  out <- cluster_texts(
    blobs$df, "text", "bullet_id",
    embed_fn = function(texts) {
      called_with <<- texts
      blobs$embeddings
    },
    seed = 1
  )
  expect_equal(called_with, blobs$df$text)
  expect_equal(nrow(out), 30)
})

test_that("randomize mode batches shuffled texts without embedding", {
  df <- data.frame(id = 1:45, text = sprintf("t%d", 1:45))
  out <- cluster_texts(
    df, "text", "id",
    embed_fn = function(texts) stop("embed_fn must not be called"),
    randomize = TRUE, batch_size = 20, seed = 3
  )
  expect_equal(nrow(out), 45)
  expect_equal(as.integer(table(out$cluster_id)), c(20L, 20L, 5L))
  expect_equal(sort(unique(out$cluster_id)), c(0L, 1L, 2L))
  expect_setequal(out$id, as.character(1:45))
  expect_null(attr(out, "embeddings"))
})

test_that("too-few texts fall back to a single cluster with a warning", {
  df <- data.frame(id = 1:5, text = sprintf("t%d", 1:5))
  expect_warning(
    out <- cluster_texts(df, "text", "id",
                         embed_fn = function(t) stop("should not embed")),
    "one cluster"
  )
  expect_equal(out$cluster_id, rep(0L, 5))
})

test_that("cluster_texts validates embedding dimensions and empty input", {
  df <- data.frame(id = 1:10, text = sprintf("t%d", 1:10))
  bad_emb <- matrix(0, nrow = 4, ncol = 8)
  expect_error(
    cluster_texts(df, "text", "id", embeddings = bad_emb, min_cluster_size = 2)
  )
  empty <- data.frame(id = 1, text = "")
  expect_error(cluster_texts(empty, "text", "id"))
})

# Live smoke test (skipped without OPENAI_API_KEY) ==========================

test_that("live: cluster_texts separates topically distinct bullets", {
  skip_if_no_key()
  df <- data.frame(
    id = 1:12,
    text = c(
      "election fraud claims spreading", "voters distrust ballot counting",
      "campaign rally misinformation", "polling place conspiracy theories",
      "senate race disinformation", "partisan media bias accusations",
      "sourdough bread baking tips", "perfect pasta sauce recipe",
      "grilling vegetables in summer", "chocolate cake frosting tricks",
      "homemade pizza dough advice", "best knife for chopping onions"
    )
  )
  out <- cluster_texts(
    df, "text", "id",
    embed_fn = function(t) ll_embed(t, model = "text-embedding-3-small"),
    min_cluster_size = 3, seed = 11
  )
  expect_equal(nrow(out), 12)
  expect_named(out, c("id", "text", "cluster_id"))

  # Politics (ids 1-6) and cooking (ids 7-12) should land in different
  # modal clusters
  merged <- merge(out, data.frame(id = as.character(1:12), topic = rep(c("pol", "cook"), each = 6)))
  modal <- vapply(split(merged$cluster_id, merged$topic), function(x) {
    as.integer(names(which.max(table(x[x != -1]))))
  }, integer(1))
  expect_false(modal[["pol"]] == modal[["cook"]])
})
