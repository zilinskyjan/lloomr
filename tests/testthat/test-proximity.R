# All offline (deterministic embed_fn / synthetic scores) ===================

prox_concepts <- function() {
  new_concepts(
    c("Media Distrust", "Press Skepticism", "Sourdough Baking"),
    c("Distrusts media?", "Skeptical of the press?", "About baking bread?"),
    active = TRUE
  )
}

# Deterministic embeddings: first two concepts nearly parallel, third
# orthogonal
fake_embed <- function(texts) {
  base <- rbind(
    c(1, 0.05, 0),
    c(0.97, 0.1, 0),
    c(0, 0, 1)
  )
  stopifnot(length(texts) == 3)
  base
}

prox_scores <- function(cc, pattern = c("aligned", "opposed")) {
  pattern <- match.arg(pattern)
  ids <- as.character(1:8)
  s1 <- c(1, 1, 0, 0, 1, 0, 1, 0)
  s2 <- if (pattern == "aligned") s1 else 1 - s1
  s3 <- c(0, 0, 1, 1, 0, 0, 0, 1)
  dplyr::bind_rows(lapply(1:3, function(i) {
    tibble::tibble(
      doc_id = ids,
      text = paste("doc", ids),
      concept_id = cc$id[i],
      concept_name = cc$name[i],
      score = list(s1, s2, s3)[[i]],
      rationale = "", highlight = "", concept_seed = NA_character_
    )
  }))
}

test_that("concept_similarity (embedding) reflects semantic closeness", {
  cc <- prox_concepts()
  passed_texts <- NULL
  sim <- concept_similarity(cc, method = "embedding",
                            embed_fn = function(t) { passed_texts <<- t; fake_embed(t) })

  expect_equal(dim(sim), c(3, 3))
  expect_equal(rownames(sim), cc$name)
  expect_equal(diag(sim), rep(1, 3), ignore_attr = TRUE)
  expect_equal(sim, t(sim))
  expect_gt(sim["Media Distrust", "Press Skepticism"], 0.99)
  expect_lt(sim["Media Distrust", "Sourdough Baking"], 0.1)
  # Concepts are embedded as "name: prompt"
  expect_equal(passed_texts[1], "Media Distrust: Distrusts media?")
})

test_that("concept_similarity (scores) reflects empirical co-matching", {
  cc <- prox_concepts()
  sim <- concept_similarity(cc, method = "scores",
                            score_df = prox_scores(cc, "aligned"), id_col = "doc_id")
  expect_equal(sim["Media Distrust", "Press Skepticism"], 1)

  sim_opp <- concept_similarity(cc, method = "scores",
                                score_df = prox_scores(cc, "opposed"), id_col = "doc_id")
  expect_equal(sim_opp["Media Distrust", "Press Skepticism"], -1)

  # Requirements and edge handling
  expect_error(concept_similarity(cc, method = "scores"), "score_df")
  expect_error(concept_similarity(cc[1, ], method = "embedding",
                                  embed_fn = fake_embed))

  # Concepts missing from score_df are dropped with a warning
  extra <- dplyr::bind_rows(cc, new_concepts("Unscored", "Never scored?"))
  class(extra) <- class(cc)
  expect_warning(
    sim_part <- concept_similarity(extra, method = "scores",
                                   score_df = prox_scores(cc), id_col = "doc_id"),
    "dropped"
  )
  expect_equal(dim(sim_part), c(3, 3))
})

test_that("zero-variance concepts get similarity 0, not NA", {
  cc <- prox_concepts()
  scores <- prox_scores(cc)
  scores$score[scores$concept_name == "Sourdough Baking"] <- 0  # constant
  sim <- concept_similarity(cc, method = "scores", score_df = scores, id_col = "doc_id")
  expect_false(anyNA(sim))
  expect_equal(sim["Sourdough Baking", "Media Distrust"], 0)
  expect_equal(sim["Sourdough Baking", "Sourdough Baking"], 1)
})

test_that("concept_similarity (centroids) measures matched-document territory", {
  cc <- prox_concepts()
  # Docs 1-4: politics-flavored embeddings; docs 5-8: baking-flavored.
  # "Media Distrust" matches docs 1-2, "Press Skepticism" matches docs 3-4
  # (DISJOINT sets, same territory); "Sourdough Baking" matches docs 5-6.
  doc_vecs <- rbind(
    c(1, 0.1, 0), c(0.95, 0.15, 0), c(0.9, 0.05, 0), c(1, 0.12, 0),
    c(0, 0, 1), c(0.05, 0, 0.95), c(0, 0.05, 1), c(0.02, 0, 1)
  )
  embed_by_text <- function(texts) {
    idx <- as.integer(sub("doc ", "", texts))
    doc_vecs[idx, , drop = FALSE]
  }
  ids <- as.character(1:8)
  score_df <- dplyr::bind_rows(lapply(1:3, function(i) {
    match_ids <- list(c("1", "2"), c("3", "4"), c("5", "6"))[[i]]
    tibble::tibble(
      doc_id = ids, text = paste("doc", ids),
      concept_id = cc$id[i], concept_name = cc$name[i],
      score = as.numeric(ids %in% match_ids),
      rationale = "", highlight = "", concept_seed = NA_character_
    )
  }))

  sim <- concept_similarity(cc, method = "centroids",
                            score_df = score_df, id_col = "doc_id",
                            embed_fn = embed_by_text)
  # Disjoint matches, same semantic territory -> centroid-close
  expect_gt(sim["Media Distrust", "Press Skepticism"], 0.99)
  expect_lt(sim["Media Distrust", "Sourdough Baking"], 0.15)
  expect_equal(diag(sim), rep(1, 3), ignore_attr = TRUE)

  # ... while score correlation sees the SAME pair as anti-correlated
  sim_scores <- concept_similarity(cc, method = "scores",
                                   score_df = score_df, id_col = "doc_id")
  expect_lt(sim_scores["Media Distrust", "Press Skepticism"], 0)

  # Precomputed doc_embeddings path (no embed_fn call)
  pre <- doc_vecs
  rownames(pre) <- ids
  sim_pre <- concept_similarity(cc, method = "centroids",
                                score_df = score_df, id_col = "doc_id",
                                embed_fn = function(t) stop("must not embed"),
                                doc_embeddings = pre)
  expect_equal(sim, sim_pre)

  # Missing rownames in precomputed embeddings -> clear error
  bad <- pre[1:3, , drop = FALSE]
  expect_error(
    concept_similarity(cc, method = "centroids", score_df = score_df,
                       id_col = "doc_id", doc_embeddings = bad),
    "missing from"
  )

  # Concept with no matches at threshold is dropped with a warning
  score_df2 <- score_df
  score_df2$score[score_df2$concept_name == "Sourdough Baking"] <- 0.5
  expect_warning(
    sim_drop <- concept_similarity(cc, method = "centroids",
                                   score_df = score_df2, id_col = "doc_id",
                                   embed_fn = embed_by_text),
    "no matches"
  )
  expect_equal(dim(sim_drop), c(2, 2))
  # ... but lowering the threshold restores it
  sim_low <- concept_similarity(cc, method = "centroids",
                                score_df = score_df2, id_col = "doc_id",
                                embed_fn = embed_by_text, threshold = 0.5)
  expect_equal(dim(sim_low), c(3, 3))

  expect_error(concept_similarity(cc, method = "centroids"), "score_df")
})

test_that("lloom_concept_map supports the centroids method", {
  skip_if_not_installed("ggplot2")
  cc <- prox_concepts()
  docs <- data.frame(doc_id = as.character(1:8), text = paste("doc", 1:8))
  sess <- lloom_session(docs, "text", "doc_id",
                        distill_chat = "f", synth_chat = "f", score_chat = "f")
  sess$concepts <- cc
  sess$score_df <- prox_scores(cc)
  sess$embed_fn <- function(texts) {
    matrix(rep(seq_along(texts), each = 3), ncol = 3, byrow = TRUE) + 0.5
  }
  p <- lloom_concept_map(sess, method = "centroids")
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$subtitle, "centroids")
  expect_equal(dim(attr(p, "similarity")), c(3, 3))
})

test_that("lloom_concept_map returns a labeled scatter with attributes", {
  skip_if_not_installed("ggplot2")
  cc <- prox_concepts()
  docs <- data.frame(doc_id = as.character(1:8), text = paste("doc", 1:8))
  sess <- lloom_session(docs, "text", "doc_id",
                        distill_chat = "f", synth_chat = "f", score_chat = "f")
  sess$concepts <- cc
  sess$score_df <- prox_scores(cc)

  p <- lloom_concept_map(sess, method = "scores")
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_setequal(geoms, c("GeomPoint", "GeomText"))

  sim <- attr(p, "similarity")
  expect_equal(dim(sim), c(3, 3))
  coords <- attr(p, "coords")
  expect_equal(dim(coords), c(3, 2))
  # MDS places the aligned pair closer than the unrelated concept
  d <- as.matrix(stats::dist(coords))
  expect_lt(d["Media Distrust", "Press Skepticism"],
            d["Media Distrust", "Sourdough Baking"])

  # Embedding method via injected embed_fn (no API)
  p2 <- lloom_concept_map(sess, method = "embedding", embed_fn = fake_embed)
  expect_s3_class(p2, "ggplot")

  # Guard: needs at least 3 active concepts
  sess$concepts$active <- c(TRUE, TRUE, FALSE)
  expect_error(lloom_concept_map(sess, method = "scores"), "at least 3")
})
