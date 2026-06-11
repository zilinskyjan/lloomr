test_that("lloom_type returns ellmer type objects for every step", {
  steps <- c(
    "distill_filter", "distill_summarize", "synthesize",
    "review_remove", "review_remove_seed", "review_merge", "review_select",
    "score", "score_highlight", "summarize_concept", "auto_eval"
  )
  for (step in steps) {
    type <- lloom_type(step)
    expect_true(inherits(type, "S7_object"), label = paste("step:", step))
  }
  expect_error(lloom_type("bogus"), "Unknown step")
})

test_that("schemas have the expected fields and constraints", {
  obj_props <- function(type) S7::prop(type, "properties")
  arr_items <- function(type) S7::prop(type, "items")

  synth <- lloom_type("synthesize")
  pattern_props <- obj_props(arr_items(obj_props(synth)$patterns))
  expect_setequal(names(pattern_props), c("name", "prompt", "example_ids"))

  score <- lloom_type("score")
  result_props <- obj_props(arr_items(obj_props(score)$pattern_results))
  expect_setequal(names(result_props), c("example_id", "rationale", "answer"))
  expect_setequal(S7::prop(result_props$answer, "values"), c("A", "B", "C", "D", "E"))

  # highlight variant adds an optional quote field
  score_hl <- lloom_type("score_highlight")
  hl_props <- obj_props(arr_items(obj_props(score_hl)$pattern_results))
  expect_true("quote" %in% names(hl_props))
  expect_false(S7::prop(hl_props$quote, "required"))
  expect_true(S7::prop(hl_props$answer, "required"))
})
