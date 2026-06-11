# Mocked tests (no network) =================================================

docs_df <- function() {
  data.frame(
    post_id = c(101, 102, 103),
    text = c(
      "The economy is rigged against ordinary people.",
      "I do not trust anything the mainstream media says anymore.",
      "Lovely weather today in Boston."
    )
  )
}

test_that("distill_filter returns newline-joined quotes per document", {
  captured_prompts <- NULL
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      captured_prompts <<- prompts
      out <- list(
        list(relevant_quotes = list("economy is rigged", "ordinary people")),
        list(relevant_quotes = list("do not trust", "mainstream media")),
        list(relevant_quotes = list("Lovely weather"))
      )
      attr(out, "usage") <- data.frame(provider = "x", model = "y", input = 5, output = 2)
      out
    }
  )
  out <- distill_filter(docs_df(), "text", "post_id", chat = "fake", n_quotes = 2)

  expect_named(out, c("post_id", "text"))
  expect_equal(out$post_id, c("101", "102", "103"))  # IDs coerced to character
  expect_equal(out$text[1], "economy is rigged\nordinary people")
  expect_equal(out$text[3], "Lovely weather")
  expect_s3_class(attr(out, "usage"), "data.frame")

  # Prompts include the document text, n_quotes, and default seeding phrase
  expect_length(captured_prompts, 3)
  expect_match(captured_prompts[1], "economy is rigged against", fixed = TRUE)
  expect_match(captured_prompts[1], "Extract 2 QUOTES", fixed = TRUE)
  expect_match(captured_prompts[1], "MOST IMPORTANT", fixed = TRUE)
})

test_that("distill_filter applies seed and drops failed documents", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "RELATED TO MEDIA DISTRUST", fixed = TRUE)
      list(
        list(relevant_quotes = list("quote a")),
        NULL,  # failed query
        list(relevant_quotes = list())  # parsed but empty
      )
    }
  )
  out <- distill_filter(docs_df(), "text", "post_id", chat = "fake", seed = "media distrust")
  expect_equal(out$post_id, "101")  # 102 failed, 103 empty -> both dropped
})

test_that("distill_summarize expands bullets to one row each", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "2-4 bullet points", fixed = TRUE)
      expect_match(prompts[1], "5-8 word phrase", fixed = TRUE)
      out <- list(
        list(bullets = list("economy unfair", "people struggling")),
        list(bullets = list("media distrust")),
        NULL  # failed query
      )
      attr(out, "usage") <- data.frame(provider = "x", model = "y", input = 9, output = 4)
      out
    }
  )
  out <- distill_summarize(docs_df(), "text", "post_id", chat = "fake")

  expect_named(out, c("post_id", "text"))
  expect_equal(out$post_id, c("101", "101", "102"))   # one row per bullet
  expect_equal(out$text, c("economy unfair", "people struggling", "media distrust"))
  expect_s3_class(attr(out, "usage"), "data.frame")
})

test_that("distill operators filter empty rows and validate custom prompts", {
  df <- rbind(docs_df(), data.frame(post_id = 104, text = ""))
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_length(prompts, 3)  # empty row excluded before prompting
      lapply(seq_along(prompts), function(i) list(bullets = list("b")))
    }
  )
  out <- distill_summarize(df, "text", "post_id", chat = "fake")
  expect_false("104" %in% out$post_id)

  expect_error(
    distill_filter(df, "text", "post_id", chat = "fake", prompt_template = "no fields"),
    "missing required template field"
  )
  expect_error(
    distill_summarize(df, "text", "post_id", chat = "fake", prompt_template = "{ex} only"),
    "missing required template field"
  )
})

test_that("distill operators error on all-empty input", {
  df <- data.frame(post_id = 1, text = "")
  expect_error(distill_filter(df, "text", "post_id", chat = "fake"))
  expect_error(distill_summarize(df, "text", "post_id", chat = "fake"))
})

# Live smoke tests (skipped without OPENAI_API_KEY) =========================

test_that("live: distill pipeline extracts quotes then bullets from real posts", {
  skip_if_no_key()
  df <- data.frame(
    post_id = 1:3,
    text = c(
      "BREAKING: New report shows the government hid inflation data for months. The numbers were cooked and the press said nothing. Wake up people, you are being lied to by the institutions you trust.",
      "Just got back from the farmers market. Tomatoes are incredible this time of year! Support your local growers, folks.",
      "Why does every single news channel run the same exact headline within minutes of each other? This is not journalism, this is coordination. Think for yourselves."
    )
  )
  chat <- live_chat()

  quotes <- distill_filter(df, "text", "post_id", chat, n_quotes = 2)
  expect_equal(nrow(quotes), 3)
  expect_named(quotes, c("post_id", "text"))
  expect_true(all(nchar(quotes$text) > 0))

  bullets <- distill_summarize(quotes, "text", "post_id", chat, n_bullets = "1-2")
  expect_gte(nrow(bullets), 3)
  expect_true(all(bullets$post_id %in% quotes$post_id))
  expect_true(all(nchar(bullets$text) > 0))
  usage <- attr(bullets, "usage")
  expect_gt(sum(usage$input), 0)
})
