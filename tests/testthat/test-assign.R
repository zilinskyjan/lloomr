# Mocked tests (no network) =================================================

assign_docs <- function() {
  data.frame(
    post_id = as.character(1:4),
    text = c("vaccines work", "media lies", "nice weather", "get vaccinated")
  )
}

assign_topics_fixture <- function() {
  new_concepts(
    name = c("Vaccine Trust", "Media Distrust"),
    prompt = c("Promotes vaccines?", "Distrusts media?")
  )
}

test_that("assign_topics returns exactly one topic per document", {
  captured <- list()
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      captured$prompts <<- prompts
      captured$type <<- type
      out <- list(
        list(assignments = list(
          list(example_id = "1", rationale = "pro-vax", topic = "Vaccine Trust"),
          list(example_id = "2", rationale = "anti-media", topic = "Media Distrust")
        )),
        list(assignments = list(
          list(example_id = "3", rationale = "fits nothing", topic = "Other"),
          list(example_id = "4", rationale = "pro-vax", topic = "Vaccine Trust")
        ))
      )
      attr(out, "usage") <- data.frame(provider = "p", model = "m", input = 1, output = 1)
      out
    }
  )
  out <- assign_topics(assign_docs(), "text", "post_id",
                       assign_topics_fixture(), chat = "fake", batch_size = 2)

  expect_equal(nrow(out), 4)
  expect_named(out, c("post_id", "text", "topic", "rationale"))
  expect_equal(out$topic, c("Vaccine Trust", "Media Distrust", "Other", "Vaccine Trust"))
  expect_equal(out$rationale[1], "pro-vax")
  expect_s3_class(attr(out, "usage"), "data.frame")

  # Prompts: batched, contain topic descriptions and the Other instruction
  expect_length(captured$prompts, 2)
  expect_match(captured$prompts[1], "Vaccine Trust: Promotes vaccines?", fixed = TRUE)
  expect_match(captured$prompts[1], 'assign "Other"', fixed = TRUE)

  # Schema constrains topic to the fixed label set (+ Other)
  topic_type <- S7::prop(S7::prop(S7::prop(captured$type, "properties")$assignments,
                                  "items"), "properties")$topic
  expect_setequal(S7::prop(topic_type, "values"),
                  c("Vaccine Trust", "Media Distrust", "Other"))
})

test_that("assign_topics with allow_other = FALSE forces a topic choice", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_false(grepl("Other", prompts[1], fixed = TRUE))
      topic_type <- S7::prop(S7::prop(S7::prop(type, "properties")$assignments,
                                      "items"), "properties")$topic
      expect_setequal(S7::prop(topic_type, "values"),
                      c("Vaccine Trust", "Media Distrust"))
      list(list(assignments = lapply(1:4, function(i) {
        list(example_id = as.character(i), rationale = "r", topic = "Vaccine Trust")
      })))
    }
  )
  out <- assign_topics(assign_docs(), "text", "post_id", assign_topics_fixture(),
                       chat = "fake", allow_other = FALSE, batch_size = 10)
  expect_true(all(out$topic == "Vaccine Trust"))
})

test_that("assign_topics handles failures, bad ids, invented topics, duplicates", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      list(
        NULL,  # batch failed
        list(assignments = list(
          list(example_id = "99", rationale = "bad id", topic = "Vaccine Trust"),
          list(example_id = "3", rationale = "invented", topic = "Brand New Topic"),
          list(example_id = "4", rationale = "first", topic = "Vaccine Trust"),
          list(example_id = "4", rationale = "dup", topic = "Media Distrust")
        ))
      )
    }
  )
  expect_warning(
    out <- assign_topics(assign_docs(), "text", "post_id", assign_topics_fixture(),
                         chat = "fake", batch_size = 2),
    "topic set to NA"
  )
  expect_equal(nrow(out), 4)
  expect_true(all(is.na(out$topic[out$post_id %in% c("1", "2", "3")])))
  expect_equal(out$topic[out$post_id == "4"], "Vaccine Trust")  # first kept
})

test_that("assign_topics accepts a bare character vector of topics", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "- Economy\n- Health", fixed = TRUE)
      list(list(assignments = lapply(1:4, function(i) {
        list(example_id = as.character(i), rationale = "r", topic = "Economy")
      })))
    }
  )
  out <- assign_topics(assign_docs(), "text", "post_id", c("Economy", "Health"),
                       chat = "fake", batch_size = 10)
  expect_true(all(out$topic == "Economy"))
  expect_error(
    assign_topics(assign_docs(), "text", "post_id", c("A", "A"), chat = "fake")
  )
})

test_that("slot_by_score picks the argmax with explicit tie and Other handling", {
  cc <- assign_topics_fixture()
  score_df <- tidyr::expand_grid(
    post_id = as.character(1:4),
    concept_i = 1:2
  )
  score_df$text <- paste("doc", score_df$post_id)
  score_df$concept_id <- cc$id[score_df$concept_i]
  score_df$concept_name <- cc$name[score_df$concept_i]
  # doc 1: clear winner; doc 2: tie at 1; doc 3: below threshold; doc 4: 0.75 winner
  score_df$score <- c(1, 0.25,   1, 1,   0.5, 0.25,   0.5, 0.75)

  out <- slot_by_score(score_df, "post_id")
  expect_equal(nrow(out), 4)
  expect_equal(out$topic[out$post_id == "1"], "Vaccine Trust")
  expect_false(out$tie[out$post_id == "1"])
  expect_equal(out$topic[out$post_id == "2"], "Vaccine Trust")  # first wins
  expect_true(out$tie[out$post_id == "2"])
  expect_equal(out$topic[out$post_id == "3"], "Other")
  expect_equal(out$topic_score[out$post_id == "3"], 0.5)
  expect_equal(out$topic[out$post_id == "4"], "Media Distrust")

  # Stricter threshold turns the 0.75 winner into Other
  out_strict <- slot_by_score(score_df, "post_id", threshold = 1)
  expect_equal(out_strict$topic[out_strict$post_id == "4"], "Other")
})

# Live smoke test (skipped without OPENAI_API_KEY) ==========================

test_that("live: assign_topics slots documents into the right single topics", {
  skip_if_no_key()
  df <- data.frame(
    post_id = as.character(1:4),
    text = c(
      "Covid vaccines are safe and effective. Get your booster today.",
      "The mainstream press hides the truth and pushes one narrative.",
      "My sourdough starter doubled overnight! Baking day tomorrow.",
      "Vaccination protects your whole community. Roll up your sleeve."
    )
  )
  out <- assign_topics(df, "text", "post_id", assign_topics_fixture(),
                       live_chat(), batch_size = 2)

  expect_equal(nrow(out), 4)
  expect_equal(out$topic[out$post_id == "1"], "Vaccine Trust")
  expect_equal(out$topic[out$post_id == "2"], "Media Distrust")
  expect_equal(out$topic[out$post_id == "3"], "Other")
  expect_equal(out$topic[out$post_id == "4"], "Vaccine Trust")
  expect_true(all(nchar(out$rationale) > 0))
})
