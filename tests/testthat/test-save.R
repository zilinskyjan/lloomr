# All offline (no LLM, no network) ==========================================

save_fixture <- function() {
  cc <- new_concepts(
    c("Media Distrust", "China-related Disinformation"),
    c("Distrusts media?", "About China disinfo?"),
    example_ids = list("1", c("2", "3")),
    active = TRUE
  )
  docs <- tibble::tibble(
    post_id = as.character(1:3),
    text = paste("doc", 1:3),
    party = c("D", "R", "D")
  )
  score_df <- tidyr::expand_grid(post_id = docs$post_id, concept_i = 1:2)
  score_df$text <- paste("doc", score_df$post_id)
  score_df$concept_id <- cc$id[score_df$concept_i]
  score_df$concept_name <- cc$name[score_df$concept_i]
  score_df$concept_prompt <- cc$prompt[score_df$concept_i]
  score_df$score <- c(1, 0, 0.75, 1, 0, 0)
  score_df$rationale <- "r"
  score_df$highlight <- ifelse(score_df$score >= 1, paste("quote", score_df$post_id), "")
  score_df$concept_seed <- NA_character_
  score_df$concept_i <- NULL

  sess <- lloom_session(docs, "text", "post_id",
                        distill_chat = "f", synth_chat = "f", score_chat = "f")
  sess$concepts <- cc
  sess$score_df <- score_df
  sess$df_filtered <- docs[, c("post_id", "text")]
  list(sess = sess, docs = docs, score_df = score_df, concepts = cc)
}

test_that("scores_wide pivots to one row per document with sanitized names", {
  fx <- save_fixture()
  wide <- scores_wide(fx$score_df, "post_id")

  expect_equal(nrow(wide), 3)
  expect_named(wide, c("post_id", "Media.Distrust", "China.related.Disinformation"))
  expect_equal(wide$Media.Distrust[wide$post_id == "1"], 1)
  expect_equal(wide$Media.Distrust[wide$post_id == "2"], 0.75)
  expect_equal(wide$China.related.Disinformation[wide$post_id == "2"], 1)

  mapping <- attr(wide, "concept_names")
  expect_equal(unname(mapping["China-related Disinformation"]),
               "China.related.Disinformation")

  # Joins back onto the source data losslessly
  merged <- dplyr::left_join(fx$docs, wide, by = "post_id")
  expect_equal(nrow(merged), nrow(fx$docs))
  expect_false(anyNA(merged$Media.Distrust))
})

test_that("scores_wide options: raw names, text column, other value columns", {
  fx <- save_fixture()
  raw <- scores_wide(fx$score_df, "post_id", sanitize_names = FALSE)
  expect_true("China-related Disinformation" %in% names(raw))

  with_text <- scores_wide(fx$score_df, "post_id", include_text = TRUE)
  expect_true("text" %in% names(with_text))
  expect_equal(nrow(with_text), 3)

  rat <- scores_wide(fx$score_df, "post_id", value_col = "rationale")
  expect_equal(rat$Media.Distrust, rep("r", 3))
})

test_that("scores_wide rejects duplicate (document, concept) pairs", {
  fx <- save_fixture()
  dup <- rbind(fx$score_df, fx$score_df[1, ])
  expect_error(scores_wide(dup, "post_id"), "Duplicate")
})

test_that("lloom_export(collapse = TRUE) flattens list columns for CSV", {
  fx <- save_fixture()
  out <- lloom_export(fx$sess, collapse = TRUE)
  expect_type(out$highlights, "character")
  expect_type(out$rep_examples, "character")
  expect_match(out$highlights[out$concept == "Media Distrust"], "quote 1")
  # And it is genuinely CSV-writable
  path <- file.path(tempdir(), "export_test.csv")
  expect_no_error(utils::write.csv(out, path, row.names = FALSE))
  expect_equal(nrow(utils::read.csv(path)), 2)
  file.remove(path)
})

test_that("lloom_write persists all artifacts and the session reloads", {
  fx <- save_fixture()
  dir <- file.path(tempdir(), "lloom_write_test")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  paths <- suppressMessages(lloom_write(fx$sess, dir, prefix = "study1"))
  expect_named(paths, c("scores_long", "scores_wide", "concepts",
                        "concept_summary", "session"))
  expect_true(all(file.exists(paths)))
  expect_true(all(startsWith(basename(paths), "study1_")))

  long <- utils::read.csv(paths["scores_long"])
  expect_equal(nrow(long), 6)  # 3 docs x 2 concepts
  expect_true(all(c("post_id", "concept_name", "score") %in% names(long)))

  wide <- utils::read.csv(paths["scores_wide"])
  expect_equal(nrow(wide), 3)

  concepts <- utils::read.csv(paths["concepts"])
  expect_equal(nrow(concepts), 2)
  expect_type(concepts$example_ids, "character")  # list column collapsed
  expect_equal(concepts$example_ids[2], "2; 3")

  reloaded <- readRDS(paths["session"])
  expect_s3_class(reloaded, "lloom_session")
  expect_equal(nrow(lloom_results(reloaded)), 6)
})

test_that("lloom_write requires a scored session", {
  fx <- save_fixture()
  fx$sess$score_df <- NULL
  expect_error(lloom_write(fx$sess, tempdir()), "lloom_score")
})
