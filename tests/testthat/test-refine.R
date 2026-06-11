# Pure-logic tests (no LLM involved) ========================================

# Build a score_df where concept match patterns are fully controlled.
# docs 1..20; concepts: generic (matches 16/20), rare (1/20), normal (6/20)
make_score_df <- function(concepts) {
  ids <- as.character(1:20)
  match_sets <- list(
    Generic = ids[1:16],
    Rare = ids[1],
    Normal = ids[3:8]
  )
  dplyr::bind_rows(lapply(seq_len(nrow(concepts)), function(i) {
    tibble::tibble(
      post_id = ids,
      text = paste("doc", ids),
      concept_id = concepts$id[i],
      concept_name = concepts$name[i],
      concept_prompt = concepts$prompt[i],
      score = ifelse(ids %in% match_sets[[concepts$name[i]]], 1, 0),
      rationale = "",
      highlight = "",
      concept_seed = NA_character_
    )
  }))
}

refine_fixture <- function() {
  new_concepts(
    name = c("Generic", "Rare", "Normal"),
    prompt = c("G?", "R?", "N?")
  )
}

test_that("refine_concepts drops generic concepts at upstream defaults", {
  cc <- refine_fixture()
  score_df <- make_score_df(cc)
  res <- suppressMessages(refine_concepts(score_df, cc))

  expect_equal(res$generic, "Generic")  # 16/20 = 0.8 >= 0.75
  expect_length(res$rare, 0)            # 1/20 = 0.05 is not < 0.05 (strict)
  expect_setequal(res$concepts$name, c("Rare", "Normal"))
})

test_that("refine_concepts threshold edges match upstream (>= generic, < rare)", {
  cc <- refine_fixture()
  score_df <- make_score_df(cc)

  # 1/20 = 0.05 exactly: NOT rare under strict < (upstream behavior)
  res <- suppressMessages(refine_concepts(score_df, cc, rare_threshold = 0.05))
  expect_false("Rare" %in% res$rare)

  # Raise rare_threshold slightly: now dropped
  res2 <- suppressMessages(refine_concepts(score_df, cc, rare_threshold = 0.06))
  expect_equal(res2$rare, "Rare")
  expect_setequal(res2$concepts$name, "Normal")

  # 16/20 = 0.8: generic at 0.8 (>=), not at 0.81
  res3 <- suppressMessages(refine_concepts(score_df, cc, generic_threshold = 0.8))
  expect_equal(res3$generic, "Generic")
  res4 <- suppressMessages(refine_concepts(score_df, cc, generic_threshold = 0.81))
  expect_length(res4$generic, 0)
})

test_that("refine_concepts ignores concepts absent from score_df", {
  cc <- refine_fixture()
  score_df <- make_score_df(cc[1:2, ])
  res <- suppressMessages(refine_concepts(score_df, cc))
  expect_true("Normal" %in% res$concepts$name)  # unscored -> kept
})

test_that("get_not_covered and get_covered_by_generic identify the right docs", {
  cc <- refine_fixture()
  score_df <- make_score_df(cc)

  # Docs 17-20 match only... Generic covers 1-16; Rare covers 1; Normal 3-8.
  # So docs 17-20 match nothing.
  expect_setequal(lloomr:::get_not_covered(score_df, "post_id"), as.character(17:20))

  # Generic concept (16/20 = 0.8 >= 0.5 fraction) is generic for coverage.
  # Upstream semantics: drop generic-concept rows, return docs with no
  # remaining matches — docs 2, 9-16 (generic-only) AND 17-20 (never covered).
  # (doc 1 also matches Rare; docs 3-8 match Normal.)
  expect_setequal(
    lloomr:::get_covered_by_generic(score_df, "post_id"),
    as.character(c(2, 9:20))
  )
})

test_that("loop_docs returns uncovered + generic-only docs, NULL when done", {
  cc <- refine_fixture()
  score_df <- make_score_df(cc)

  out <- loop_docs(score_df, "text", "post_id")
  expect_setequal(out$post_id, as.character(c(2, 9:16, 17:20)))
  expect_equal(nrow(out), 13)
  expect_equal(out$text[out$post_id == "2"], "doc 2")

  # Stop condition 1: all documents covered specifically -> zero rows -> NULL
  covered <- score_df
  covered$score <- ifelse(covered$concept_name == "Normal", 1, 0)
  expect_null(loop_docs(covered, "text", "post_id"))

  # Stop condition 2: nothing covered -> every doc returned -> NULL
  none <- score_df
  none$score <- 0
  expect_null(loop_docs(none, "text", "post_id"))
})
