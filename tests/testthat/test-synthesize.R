# Mocked tests (no network) =================================================

cluster_fixture <- function() {
  data.frame(
    post_id = c("1", "2", "3", "4", "5", "6"),
    text = c(
      "vaccines are safe", "trust the science", "get your shots",
      "media lies constantly", "fake news everywhere", "journalists biased"
    ),
    cluster_id = c(0L, 0L, 0L, 1L, 1L, 1L)
  )
}

test_that("synthesize_concepts builds concepts and assignments per cluster", {
  captured <- NULL
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      captured <<- prompts
      out <- list(
        list(patterns = list(
          list(name = "Vaccine Trust", prompt = "Does it promote vaccines?",
               example_ids = list("1", "3"))
        )),
        list(patterns = list(
          list(name = "Media Distrust", prompt = "Does it distrust media?",
               example_ids = list("4", "99"))  # 99 not in cluster
        ))
      )
      attr(out, "usage") <- data.frame(provider = "p", model = "m", input = 1, output = 1)
      out
    }
  )
  res <- synthesize_concepts(cluster_fixture(), "text", "post_id", chat = "fake")

  expect_s3_class(res$concepts, "lloom_concepts")
  expect_equal(res$concepts$name, c("Vaccine Trust", "Media Distrust"))
  expect_false(any(res$concepts$active))
  expect_identical(res$concepts$example_ids, list(c("1", "3"), c("4", "99")))
  expect_s3_class(attr(res, "usage"), "data.frame")

  # Assignments keep only exemplar ids present in the concept's cluster
  expect_equal(nrow(res$assignments), 3)  # "99" dropped
  expect_setequal(res$assignments$post_id[res$assignments$concept_name == "Vaccine Trust"],
                  c("1", "3"))
  expect_equal(res$assignments$text[res$assignments$post_id == "4"], "media lies constantly")

  # One prompt per cluster; n_concepts heuristic = ceiling(3/3) = 1 pattern
  expect_length(captured, 2)
  expect_match(captured[1], "1 unifying pattern", fixed = TRUE)
  expect_match(captured[1], "vaccines are safe", fixed = TRUE)
  expect_false(grepl("media lies", captured[1], fixed = TRUE))  # cluster isolation
})

test_that("synthesize_concepts respects n_concepts, seed, and pattern_phrase", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "up to 4 unique topics", fixed = TRUE)
      expect_match(prompts[1], "MUST BE RELATED TO VACCINES", fixed = TRUE)
      lapply(seq_along(prompts), function(i) list(patterns = list()))
    }
  )
  expect_warning(
    res <- synthesize_concepts(
      cluster_fixture(), "text", "post_id", chat = "fake",
      n_concepts = 4, seed = "vaccines", pattern_phrase = "unique topic"
    ),
    "no concepts"
  )
  expect_equal(nrow(res$concepts), 0)
})

test_that("synthesize_concepts records the seed on generated concepts", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      lapply(seq_along(prompts), function(i) {
        list(patterns = list(list(name = paste0("C", i), prompt = "P?",
                                  example_ids = list("1"))))
      })
    }
  )
  res <- synthesize_concepts(cluster_fixture(), "text", "post_id",
                             chat = "fake", seed = "vaccines")
  expect_true(all(res$concepts$seed == "vaccines"))
  expect_true(all(res$assignments$seed == "vaccines"))
})

test_that("synthesize_concepts splits large clusters into batches correctly", {
  df <- data.frame(
    post_id = as.character(1:5),
    text = paste("bullet", 1:5),
    cluster_id = 0L
  )
  captured <- NULL
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      captured <<- prompts
      list(
        list(patterns = list(list(name = "A", prompt = "A?", example_ids = list("2")))),
        list(patterns = list(list(name = "B", prompt = "B?", example_ids = list("5"))))
      )
    }
  )
  res <- synthesize_concepts(df, "text", "post_id", chat = "fake", batch_size = 3)

  expect_length(captured, 2)  # 5 docs / batch of 3 -> 2 prompts
  expect_match(captured[1], "bullet 1", fixed = TRUE)
  expect_false(grepl("bullet 4", captured[1], fixed = TRUE))
  # Each batch's concepts resolve exemplars within their own batch
  expect_equal(res$assignments$post_id[res$assignments$concept_name == "B"], "5")
})

test_that("synthesize_concepts dedupes identical concepts and survives failures", {
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      list(
        list(patterns = list(
          list(name = "Same", prompt = "Same?", example_ids = list("1")),
          list(name = "Same", prompt = "Same?", example_ids = list("2"))
        )),
        NULL  # second cluster's query failed
      )
    }
  )
  res <- synthesize_concepts(cluster_fixture(), "text", "post_id", chat = "fake")
  expect_equal(nrow(res$concepts), 1)
  expect_equal(res$assignments$post_id, "1")  # duplicate's assignment dropped

  # dedupe = FALSE keeps both
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      list(
        list(patterns = list(
          list(name = "Same", prompt = "Same?", example_ids = list("1")),
          list(name = "Same", prompt = "Same?", example_ids = list("2"))
        )),
        NULL
      )
    }
  )
  res2 <- synthesize_concepts(cluster_fixture(), "text", "post_id",
                              chat = "fake", dedupe = FALSE)
  expect_equal(nrow(res2$concepts), 2)
})
