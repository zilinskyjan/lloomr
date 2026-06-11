# Mocked tests (no network) =================================================

concepts_fixture <- function() {
  new_concepts(
    name = c("Vaccine Trust", "Media Distrust", "Press Skepticism", "Weather Talk"),
    prompt = c("Promotes vaccines?", "Distrusts media?", "Skeptical of press?", "About weather?"),
    example_ids = list("1", "4", "5", "6")
  )
}

mock_review_response <- function(payload) {
  function(chat, prompts, type, max_active = 10, rpm = 500) list(payload)
}

test_that("review_remove drops named concepts and ignores unknown names", {
  cc <- concepts_fixture()
  local_mocked_bindings(
    ll_query = mock_review_response(list(remove = list("Weather Talk", "Nonexistent")))
  )
  res <- review_remove(cc, chat = "fake")
  expect_equal(res$removed, "Weather Talk")
  expect_setequal(res$concepts$name, c("Vaccine Trust", "Media Distrust", "Press Skepticism"))
})

test_that("review_remove keeps everything when the query fails or list is empty", {
  cc <- concepts_fixture()
  # ll_query is mocked, so simulate its failure contract: a NULL result
  local_mocked_bindings(ll_query = mock_review_response(NULL))
  res <- review_remove(cc, chat = "fake")
  expect_equal(nrow(res$concepts), 4)
  expect_length(res$removed, 0)

  local_mocked_bindings(ll_query = mock_review_response(list(remove = list())))
  res2 <- review_remove(cc, chat = "fake")
  expect_equal(nrow(res2$concepts), 4)
})

test_that("review_remove uses the seeded prompt variant when seed is given", {
  cc <- concepts_fixture()
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      expect_match(prompts[1], "I have the following THEME:\nvaccination", fixed = TRUE)
      list(list(remove = list()))
    }
  )
  review_remove(cc, chat = "fake", seed = "vaccination")
})

test_that("review_merge merges valid pairs and unions example ids", {
  cc <- concepts_fixture()
  local_mocked_bindings(
    ll_query = mock_review_response(list(merge = list(
      list(original_themes = list("Media Distrust", "Press Skepticism"),
           merged_theme_name = "Anti-Media Sentiment",
           merged_theme_prompt = "Hostile toward news media?")
    )))
  )
  res <- review_merge(cc, chat = "fake")
  expect_setequal(res$concepts$name,
                  c("Vaccine Trust", "Weather Talk", "Anti-Media Sentiment"))
  merged_row <- res$concepts[res$concepts$name == "Anti-Media Sentiment", ]
  expect_setequal(merged_row$example_ids[[1]], c("4", "5"))
  expect_equal(nrow(res$merged), 1)
  expect_equal(res$merged$merged_name, "Anti-Media Sentiment")
})

test_that("review_merge skips non-pairs, unknown names, and reused concepts", {
  cc <- concepts_fixture()
  local_mocked_bindings(
    ll_query = mock_review_response(list(merge = list(
      # triple: skipped
      list(original_themes = list("A", "B", "C"),
           merged_theme_name = "X", merged_theme_prompt = "X?"),
      # unknown member: skipped
      list(original_themes = list("Vaccine Trust", "Nonexistent"),
           merged_theme_name = "Y", merged_theme_prompt = "Y?"),
      # valid
      list(original_themes = list("Media Distrust", "Press Skepticism"),
           merged_theme_name = "Anti-Media", merged_theme_prompt = "Anti?"),
      # reuses an already-consumed concept: skipped
      list(original_themes = list("Press Skepticism", "Weather Talk"),
           merged_theme_name = "Z", merged_theme_prompt = "Z?")
    )))
  )
  res <- review_merge(cc, chat = "fake")
  expect_equal(nrow(res$merged), 1)
  expect_setequal(res$concepts$name, c("Vaccine Trust", "Weather Talk", "Anti-Media"))
})

test_that("review_select activates chosen concepts and caps at max_concepts", {
  cc <- concepts_fixture()
  local_mocked_bindings(
    ll_query = mock_review_response(list(selected = list(
      "Vaccine Trust", "Media Distrust", "Weather Talk"
    )))
  )
  res <- review_select(cc, max_concepts = 2, chat = "fake")
  expect_equal(sum(res$active), 2)  # capped
  expect_true(res$active[res$name == "Vaccine Trust"])

  # Fallback: nothing usable selected -> random sample with warning
  local_mocked_bindings(ll_query = mock_review_response(list(selected = list("Bogus"))))
  expect_warning(res2 <- review_select(cc, max_concepts = 2, chat = "fake"), "random")
  expect_equal(sum(res2$active), 2)
})

test_that("review_concepts chains remove -> merge -> select and syncs assignments", {
  cc <- concepts_fixture()
  assignments <- tibble::tibble(
    post_id = c("1", "4", "5", "6"),
    text = c("t1", "t4", "t5", "t6"),
    concept_id = cc$id,
    concept_name = cc$name,
    concept_prompt = cc$prompt,
    seed = NA_character_
  )
  call_n <- 0
  local_mocked_bindings(
    ll_query = function(chat, prompts, type, max_active = 10, rpm = 500) {
      call_n <<- call_n + 1
      switch(call_n,
        list(list(remove = list("Weather Talk"))),
        list(list(merge = list(
          list(original_themes = list("Media Distrust", "Press Skepticism"),
               merged_theme_name = "Anti-Media", merged_theme_prompt = "Anti?")
        ))),
        list(list(selected = list("Anti-Media")))
      )
    }
  )
  res <- review_concepts(cc, chat = "fake", assignments = assignments, max_concepts = 1)

  expect_setequal(res$concepts$name, c("Vaccine Trust", "Anti-Media"))
  expect_equal(res$removed, "Weather Talk")
  expect_equal(sum(res$concepts$active), 1)
  expect_true(res$concepts$active[res$concepts$name == "Anti-Media"])

  # Assignments: Weather Talk's row dropped; merged rows relabeled with new id
  expect_false("6" %in% res$assignments$post_id)
  merged_id <- res$concepts$id[res$concepts$name == "Anti-Media"]
  expect_equal(res$assignments$concept_id[res$assignments$post_id %in% c("4", "5")],
               rep(merged_id, 2))
  expect_equal(unique(res$assignments$concept_prompt[res$assignments$post_id %in% c("4", "5")]),
               "Anti?")
})

# Live smoke test (skipped without OPENAI_API_KEY) ==========================

test_that("live: synthesize + review produce a coherent concept set", {
  skip_if_no_key()
  df <- data.frame(
    post_id = as.character(1:8),
    text = c(
      "covid vaccines are safe and effective",
      "get vaccinated to protect your family",
      "boosters reduce hospitalization risk",
      "vaccination saves lives",
      "mainstream media spreads fake news",
      "journalists hide the truth from you",
      "news channels coordinate their headlines",
      "the press is bought and paid for"
    ),
    cluster_id = rep(c(0L, 1L), each = 4)
  )
  chat <- live_chat()

  synth <- synthesize_concepts(df, "text", "post_id", chat, n_concepts = 2)
  expect_gte(nrow(synth$concepts), 2)
  expect_true(all(nchar(synth$concepts$name) > 0))
  expect_true(all(nchar(synth$concepts$prompt) > 0))

  reviewed <- review_concepts(synth$concepts, chat,
                              assignments = synth$assignments, max_concepts = 2)
  expect_gte(nrow(reviewed$concepts), 1)
  expect_lte(sum(reviewed$concepts$active), 2)
  expect_gte(sum(reviewed$concepts$active), 1)
})
