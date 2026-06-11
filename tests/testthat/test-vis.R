# All offline (no LLM, no network) ==========================================

# 6 docs: p1-p4 party D, p5-p6 party R.
# Concept A matches p1, p2, p5; concept B matches p1 only; p4, p6 outliers;
# p3 matches B at 0.75 (below default threshold).
vis_fixture <- function() {
  cc <- new_concepts(c("A", "B"), c("Is A?", "Is B?"),
                     example_ids = list(c("p1", "p2"), "p1"))
  docs <- tibble::tibble(
    post_id = paste0("p", 1:6),
    text = paste("text", 1:6),
    party = c("D", "D", "D", "D", "R", "R"),
    likes = c(10, 20, 30, 40, 50, 60)
  )
  score_df <- tidyr::expand_grid(post_id = docs$post_id, concept_i = 1:2)
  score_df$text <- paste("text", as.integer(sub("p", "", score_df$post_id)))
  score_df$concept_id <- cc$id[score_df$concept_i]
  score_df$concept_name <- cc$name[score_df$concept_i]
  score_df$concept_prompt <- cc$prompt[score_df$concept_i]
  score_df$score <- 0
  score_df$score[score_df$post_id %in% c("p1", "p2", "p5") & score_df$concept_name == "A"] <- 1
  score_df$score[score_df$post_id == "p1" & score_df$concept_name == "B"] <- 1
  score_df$score[score_df$post_id == "p3" & score_df$concept_name == "B"] <- 0.75
  score_df$rationale <- ""
  score_df$highlight <- ifelse(score_df$score >= 1, paste("quote", score_df$post_id), "")
  score_df$concept_seed <- NA_character_

  sess <- lloom_session(docs, "text", "post_id",
                        distill_chat = "f", synth_chat = "f", score_chat = "f")
  cc$active <- TRUE
  sess$concepts <- cc
  sess$score_df <- score_df
  sess$df_filtered <- docs[, c("post_id", "text")]
  list(sess = sess, docs = docs, score_df = score_df, concepts = cc)
}

test_that("concept_matrix counts matches, outliers, and slice sizes", {
  fx <- vis_fixture()
  mat <- concept_matrix(fx$score_df, "post_id",
                        slice_df = fx$docs, slice_col = "party")

  expect_setequal(unique(mat$slice), c("All", "D", "R"))
  get_n <- function(s, c) mat$n[mat$slice == s & mat$concept == c]
  expect_equal(get_n("All", "A"), 3L)
  expect_equal(get_n("All", "B"), 1L)
  expect_equal(get_n("All", "Outlier"), 3L)  # p3 (0.75 < 1), p4, p6
  expect_equal(get_n("D", "A"), 2L)
  expect_equal(get_n("R", "A"), 1L)
  expect_equal(get_n("R", "B"), 0L)
  expect_equal(unique(mat$slice_size[mat$slice == "D"]), 4L)
  expect_equal(mat$value, mat$n)  # norm_by = "none" default
})

test_that("concept_matrix respects threshold and normalization", {
  fx <- vis_fixture()
  # Lower threshold: p3's 0.75 on B now counts
  mat75 <- concept_matrix(fx$score_df, "post_id", threshold = 0.75)
  expect_equal(mat75$n[mat75$concept == "B"], 2L)
  expect_equal(mat75$n[mat75$concept == "Outlier"], 2L)

  m_slice <- concept_matrix(fx$score_df, "post_id", slice_df = fx$docs,
                            slice_col = "party", norm_by = "slice")
  expect_equal(m_slice$value[m_slice$slice == "D" & m_slice$concept == "A"], 2 / 4)
  expect_equal(m_slice$value[m_slice$slice == "R" & m_slice$concept == "A"], 1 / 2)

  m_concept <- concept_matrix(fx$score_df, "post_id", slice_df = fx$docs,
                              slice_col = "party", norm_by = "concept")
  expect_equal(m_concept$value[m_concept$slice == "D" & m_concept$concept == "A"], 2 / 3)
  # Zero-total concepts normalize to 0, not NaN
  expect_false(any(is.nan(m_concept$value)))

  no_out <- concept_matrix(fx$score_df, "post_id", include_outlier = FALSE)
  expect_false("Outlier" %in% no_out$concept)
})

test_that("concept_matrix bins numeric slice columns by quantile", {
  fx <- vis_fixture()
  mat <- concept_matrix(fx$score_df, "post_id", slice_df = fx$docs,
                        slice_col = "likes", max_slice_bins = 2)
  bins <- setdiff(unique(mat$slice), "All")
  expect_length(bins, 2)
  expect_equal(sum(unique(mat[mat$slice != "All", c("slice", "slice_size")])$slice_size), 6L)
})

test_that("lloom_vis returns a labeled ggplot heatmap", {
  skip_if_not_installed("ggplot2")
  fx <- vis_fixture()
  p <- lloom_vis(fx$sess, slice_col = "party")
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_setequal(geoms, c("GeomTile", "GeomText"))
  # Default normalization when slicing is by slice share
  expect_match(rlang::as_label(p$mapping$fill), "value")

  built <- ggplot2::ggplot_build(p)
  expect_gt(nrow(built$data[[1]]), 0)

  # Errors before scoring
  sess0 <- fx$sess
  sess0$score_df <- NULL
  expect_error(lloom_vis(sess0), "lloom_score")
})

test_that("lloom_export produces the per-concept evidence table", {
  fx <- vis_fixture()
  out <- lloom_export(fx$sess)

  expect_named(out, c("concept", "criteria", "summary", "rep_examples",
                      "prevalence", "n_matches", "highlights"))
  a <- out[out$concept == "A", ]
  expect_equal(a$n_matches, 3L)
  expect_equal(a$prevalence, 0.5)  # 3 of 6 docs
  expect_setequal(a$highlights[[1]], c("quote p1", "quote p2", "quote p5"))
  expect_setequal(a$rep_examples[[1]], c("text 1", "text 2"))
  b <- out[out$concept == "B", ]
  expect_equal(b$n_matches, 1L)

  # max_highlights caps the quotes
  capped <- lloom_export(fx$sess, max_highlights = 1)
  expect_length(capped$highlights[[which(capped$concept == "A")]], 1)

  # Inactive concepts are excluded
  sess2 <- fx$sess
  sess2$concepts$active <- c(TRUE, FALSE)
  expect_equal(lloom_export(sess2)$concept, "A")
})
