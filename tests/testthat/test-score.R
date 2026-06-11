# Mocked tests (no network) =================================================

score_docs <- function() {
  data.frame(
    post_id = as.character(1:4),
    text = c("vaccines work", "media lies", "nice weather", "get vaccinated")
  )
}

score_concepts_fixture <- function() {
  new_concepts(
    name = c("Vaccine Trust", "Media Distrust"),
    prompt = c("Promotes vaccines?", "Distrusts media?"),
    seed = "health"
  )
}

test_that("score_concepts produces the full doc x concept grid with mapped scores", {
  captured <- NULL
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      captured <<- prompts
      # 2 concepts x 2 batches (batch_size = 2) = 4 prompts
      out <- list(
        list(pattern_results = list(
          list(example_id = "1", rationale = "promotes", answer = "A"),
          list(example_id = "2", rationale = "no", answer = "E")
        )),
        list(pattern_results = list(
          list(example_id = "3", rationale = "no", answer = "D"),
          list(example_id = "4", rationale = "yes", answer = "B")
        )),
        list(pattern_results = list(
          list(example_id = "1", rationale = "no", answer = "E"),
          list(example_id = "2", rationale = "yes", answer = "A")
        )),
        list(pattern_results = list(
          list(example_id = "3", rationale = "no", answer = "E"),
          list(example_id = "4", rationale = "no", answer = "C")
        ))
      )
      attr(out, "usage") <- data.frame(provider = "p", model = "m", input = 1, output = 1)
      out
    }
  )
  cc <- score_concepts_fixture()
  out <- score_concepts(score_docs(), "text", "post_id", cc, chat = "fake", batch_size = 2)

  expect_equal(nrow(out), 8)  # 4 docs x 2 concepts
  expect_named(out, c("post_id", "text", "concept_id", "concept_name",
                      "concept_prompt", "score", "rationale", "highlight",
                      "concept_seed"))
  vt <- out[out$concept_name == "Vaccine Trust", ]
  expect_equal(vt$score[vt$post_id == "1"], 1)      # A
  expect_equal(vt$score[vt$post_id == "2"], 0)      # E
  expect_equal(vt$score[vt$post_id == "4"], 0.75)   # B
  md <- out[out$concept_name == "Media Distrust", ]
  expect_equal(md$score[md$post_id == "2"], 1)      # A
  expect_equal(md$score[md$post_id == "4"], 0.5)    # C
  expect_equal(vt$rationale[vt$post_id == "1"], "promotes")
  expect_true(all(out$highlight == ""))             # no highlights requested
  expect_true(all(out$concept_seed == "health"))
  expect_s3_class(attr(out, "usage"), "data.frame")

  # Prompts: 4 total; each contains concept name and the batch's docs
  expect_length(captured, 4)
  expect_match(captured[1], "Vaccine Trust", fixed = TRUE)
  expect_match(captured[1], "vaccines work", fixed = TRUE)
  expect_false(grepl("nice weather", captured[1], fixed = TRUE))
})

test_that("score_concepts backfills failures, unknown ids, and duplicates", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      list(
        NULL,  # whole batch failed -> backfill
        list(pattern_results = list(
          list(example_id = "99", rationale = "hallucinated id", answer = "A"),
          list(example_id = "3", rationale = "first", answer = "B"),
          list(example_id = "3", rationale = "dup ignored", answer = "E"),
          list(example_id = "4", answer = "A")  # no rationale field
        ))
      )
    }
  )
  cc <- score_concepts_fixture()[1, ]
  expect_warning(
    out <- score_concepts(score_docs(), "text", "post_id", cc, chat = "fake", batch_size = 2),
    "backfilled"
  )

  expect_equal(nrow(out), 4)
  expect_equal(out$score[out$post_id %in% c("1", "2")], c(0, 0))  # backfilled
  expect_equal(out$rationale[out$post_id == "1"], "")
  expect_equal(out$score[out$post_id == "3"], 0.75)  # first answer kept
  expect_equal(out$rationale[out$post_id == "3"], "first")
  expect_equal(out$score[out$post_id == "4"], 1)
  expect_false("99" %in% out$post_id)
})

test_that("score_concepts captures highlights when requested", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "QUOTE exactly copied", fixed = TRUE)
      list(list(pattern_results = list(
        list(example_id = "1", rationale = "r", answer = "A", quote = "vaccines work"),
        list(example_id = "2", rationale = "r", answer = "E"),  # quote optional
        list(example_id = "3", rationale = "r", answer = "E"),
        list(example_id = "4", rationale = "r", answer = "A", quote = "get vaccinated")
      )))
    }
  )
  cc <- score_concepts_fixture()[1, ]
  out <- score_concepts(score_docs(), "text", "post_id", cc, chat = "fake",
                        batch_size = 10, get_highlights = TRUE)
  expect_equal(out$highlight[out$post_id == "1"], "vaccines work")
  expect_equal(out$highlight[out$post_id == "2"], "")
})

test_that("score_concepts rejects duplicate document ids", {
  df <- rbind(score_docs(), data.frame(post_id = "1", text = "dup"))
  expect_error(
    score_concepts(df, "text", "post_id", score_concepts_fixture(), chat = "fake")
  )
})

test_that("summarize_concept summarizes matched highlights above threshold", {
  cc <- score_concepts_fixture()
  score_df <- tibble::tibble(
    post_id = c("1", "2", "3"),
    text = c("t1", "t2", "t3"),
    concept_id = cc$id[1],
    concept_name = "Vaccine Trust",
    concept_prompt = "Promotes vaccines?",
    score = c(1, 1, 0.5),
    rationale = "",
    highlight = c("vaccines work", "get vaccinated", "below threshold"),
    concept_seed = NA_character_
  )
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "Vaccine Trust", fixed = TRUE)
      expect_match(prompts[1], "vaccines work", fixed = TRUE)
      expect_false(grepl("below threshold", prompts[1], fixed = TRUE))
      list(list(summary = "People endorse vaccination."))
    }
  )
  s <- summarize_concept(score_df, cc$id[1], chat = "fake")
  expect_equal(s, "People endorse vaccination.")

  # No matches above threshold -> NA without any LLM call
  local_mocked_bindings(
    ll_query = function(...) stop("must not be called")
  )
  expect_equal(summarize_concept(score_df, cc$id[2], chat = "fake"), NA_character_)
  expect_equal(summarize_concept(score_df, cc$id[1], chat = "fake", threshold = 2), NA_character_)
})

# Live smoke test (skipped without OPENAI_API_KEY) ==========================

test_that("live: score_concepts discriminates on-topic from off-topic docs", {
  skip_if_no_key()
  df <- data.frame(
    post_id = as.character(1:4),
    text = c(
      "Covid vaccines are safe, effective, and save lives. Get your booster today.",
      "Everyone should get vaccinated to protect their community from the virus.",
      "My sourdough starter finally doubled overnight! Baking day tomorrow.",
      "Top tips for grilling vegetables: high heat, a little oil, don't crowd the pan."
    )
  )
  cc <- new_concepts(
    name = "Vaccine Promotion",
    prompt = "Does the text example promote or encourage vaccination?"
  )
  out <- score_concepts(df, "text", "post_id", cc, live_chat(),
                        batch_size = 2, get_highlights = TRUE)

  expect_equal(nrow(out), 4)
  expect_true(all(out$score %in% c(0, 0.25, 0.5, 0.75, 1)))
  on_topic <- mean(out$score[out$post_id %in% c("1", "2")])
  off_topic <- mean(out$score[out$post_id %in% c("3", "4")])
  expect_gt(on_topic, 0.7)
  expect_lt(off_topic, 0.3)
  # Highlights for matches come from the source text
  hl <- out$highlight[out$post_id == "1"]
  expect_gt(nchar(hl), 0)
})
