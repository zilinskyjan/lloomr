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
