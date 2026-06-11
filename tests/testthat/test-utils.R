test_that("letter_to_score maps A-E per upstream parse_bucketed_score", {
  expect_equal(
    letter_to_score(c("A", "B", "C", "D", "E")),
    c(1, 0.75, 0.5, 0.25, 0)
  )
  # Case-insensitive, first character wins, whitespace tolerated
  expect_equal(letter_to_score(c("a", " b ", "C: neither")), c(1, 0.75, 0.5))
  # Unrecognized values -> NAN_SCORE (0), matching upstream
  expect_equal(letter_to_score(c("F", "", "junk")), c(0, 0, 0))
  expect_equal(letter_to_score(NA), 0)
  expect_length(letter_to_score(character(0)), 0)
})

test_that("filter_empty_rows drops NA and zero-length text", {
  df <- data.frame(
    id = 1:4,
    text = c("keep", "", NA, "also keep"),
    stringsAsFactors = FALSE
  )
  out <- filter_empty_rows(df, "text")
  expect_equal(out$id, c(1L, 4L))
  expect_error(filter_empty_rows(df, "missing_col"))
})

test_that("examples_to_json produces the upstream cur_examples shape", {
  df <- data.frame(doc_id = c(10, 11), text = c('He said "hi"', "Second doc"))
  json <- examples_to_json(df, "doc_id", "text")
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_named(parsed, "cur_examples")
  expect_length(parsed$cur_examples, 2)
  expect_equal(parsed$cur_examples[[1]]$example_id, "10")  # IDs coerced to chr
  expect_equal(parsed$cur_examples[[1]]$example_text, 'He said "hi"')
})

test_that("robust_json_parse recovers JSON from messy LLM output", {
  # Plain JSON
  expect_equal(
    robust_json_parse('{"bullets": ["a", "b"]}', top_level_key = "bullets"),
    list("a", "b")
  )
  # Markdown fences and chatter
  messy <- 'Sure! Here you go:\n```json\n{"remove": ["X"]}\n```\nHope that helps.'
  expect_equal(robust_json_parse(messy, top_level_key = "remove"), list("X"))
  # Missing key returns the whole object
  expect_named(robust_json_parse('{"a": 1}', top_level_key = "b"), "a")
  # Garbage and edge cases return NULL
  expect_null(robust_json_parse("no json here"))
  expect_null(robust_json_parse('{"truncated": ['))
  expect_null(robust_json_parse(NULL))
  expect_null(robust_json_parse(NA_character_))
})

test_that("new_id produces unique well-formed ids", {
  ids <- lloomr:::new_id(500)
  expect_length(unique(ids), 500)
  expect_true(all(grepl("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", ids)))
})

test_that("seeding_phrase mirrors upstream per-step behavior", {
  sp <- lloomr:::seeding_phrase
  expect_equal(sp(NULL, "distill_filter"), "MOST IMPORTANT")
  expect_equal(sp("vaccines", "distill_filter"), "RELATED TO VACCINES")
  expect_equal(sp(NULL, "distill_summarize"), "")
  expect_equal(sp("vaccines", "distill_summarize"), "RELATED TO VACCINES")
  expect_equal(sp(NULL, "synthesize"), "")
  expect_equal(sp("vaccines", "synthesize"), "The patterns MUST BE RELATED TO VACCINES.")
  expect_error(sp(NULL, "bogus"), "Unknown step")
})
