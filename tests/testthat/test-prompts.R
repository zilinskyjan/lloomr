test_that("lloom_prompt returns templates for all steps and errors on unknown", {
  steps <- c(
    "distill_filter", "distill_summarize", "synthesize",
    "review_remove", "review_remove_seed", "review_merge", "review_select",
    "score", "score_highlight", "summarize_concept", "auto_eval"
  )
  for (step in steps) {
    tmpl <- lloom_prompt(step)
    expect_type(tmpl, "character")
    expect_length(tmpl, 1)
    expect_gt(nchar(tmpl), 50)
  }
  expect_error(lloom_prompt("nonexistent_step"), "Unknown step")
})

test_that("every template renders cleanly with its required fields", {
  dummy_args <- list(
    ex = "Sample text.", n_quotes = 3, seeding_phrase = "MOST IMPORTANT",
    n_bullets = "2-4", n_words = "5-8",
    examples = "[]", n_concepts_phrase = "up to 5 patterns",
    concepts = "- Name: A, Prompt: B", seed = "politics", max_concepts = 5,
    examples_json = '{"cur_examples": []}', concept_name = "Test",
    concept_prompt = "Does it?", summary_length = "15-20 word",
    items = "- item_id 0: X", topics = "- Topic A: a?",
    other_clause = ' If none fits, assign "Other".'
  )
  for (step in names(lloomr:::.lloom_prompts)) {
    rendered <- render_prompt(lloom_prompt(step), dummy_args)
    # No unfilled single-brace placeholders should remain for required fields
    for (req in lloomr:::.lloom_prompt_reqs[[step]]) {
      expect_false(
        grepl(paste0("{", req, "}"), rendered, fixed = TRUE),
        label = paste0("step '", step, "' leaves '{", req, "}' unrendered")
      )
    }
  }
})

test_that("render_prompt substitutes values and preserves literal JSON braces", {
  rendered <- render_prompt(
    lloom_prompt("distill_filter"),
    list(ex = "Hello world.", n_quotes = 2, seeding_phrase = "MOST IMPORTANT")
  )
  expect_match(rendered, "Hello world.", fixed = TRUE)
  expect_match(rendered, "Extract 2 QUOTES", fixed = TRUE)
  # Doubled braces collapse to literal single braces around the JSON example
  expect_match(rendered, "{\n", fixed = TRUE)
  expect_match(rendered, "\"relevant_quotes\"", fixed = TRUE)
  expect_false(grepl("{{", rendered, fixed = TRUE))
})

test_that("render_prompt does not re-interpolate inserted values", {
  # Braces inside interpolated values must survive untouched
  json_val <- '{"cur_examples": [{"example_id": "1"}]}'
  rendered <- render_prompt(
    lloom_prompt("score"),
    list(examples_json = json_val, concept_name = "X", concept_prompt = "Y?")
  )
  expect_match(rendered, json_val, fixed = TRUE)
})

test_that("validate_prompt accepts defaults and rejects incomplete templates", {
  for (step in names(lloomr:::.lloom_prompt_reqs)) {
    expect_invisible(validate_prompt(step, lloom_prompt(step)))
  }
  expect_error(
    validate_prompt("distill_filter", "Just give me quotes from {ex}."),
    "missing required template field"
  )
  expect_error(
    validate_prompt("distill_filter", "Quotes: {ex} {n_quotes}"),
    "seeding_phrase"
  )
  expect_error(validate_prompt("nope", "x"), "Unknown step")
})

test_that("prompts match upstream wording on key instruction lines", {
  # Spot-check faithfulness to text_lloom/prompts.py
  expect_match(
    lloom_prompt("score"),
    "A: Strongly agree", fixed = TRUE
  )
  expect_match(
    lloom_prompt("review_merge"),
    "PAIRS of themes that are similar or overlapping", fixed = TRUE
  )
  expect_match(
    lloom_prompt("synthesize"),
    "2-4 word NAME for the pattern", fixed = TRUE
  )
})

test_that("distill prompts use declarative instructions (deliberate deviation)", {
  expect_match(lloom_prompt("distill_summarize"),
               "Summarize the main point", fixed = TRUE)
  expect_match(lloom_prompt("distill_filter"),
               "Extract {n_quotes} QUOTES", fixed = TRUE)
  expect_false(grepl("Please summarize", lloom_prompt("distill_summarize"), fixed = TRUE))
  expect_false(grepl("Please extract", lloom_prompt("distill_filter"), fixed = TRUE))
})
