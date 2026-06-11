# Mocked tests (no network) =================================================

session_df <- function(n = 12) {
  data.frame(
    post_id = sprintf("p%02d", 1:n),
    text = rep(c(
      "Vaccines are safe. Get your shots. Protect your family.",
      "The media lies. Do not trust the press. They coordinate stories."
    ), length.out = n)
  )
}

fake_session <- function(df = session_df(), id_col = "post_id") {
  lloom_session(
    df, "text", id_col,
    distill_chat = "fake-distill", synth_chat = "fake-synth",
    score_chat = "fake-score", embed_fn = function(t) stop("no embedding in mocks")
  )
}

test_that("lloom_session preprocesses input and validates IDs", {
  expect_message(
    sess <- lloom_session(session_df()[, "text", drop = FALSE], "text",
                          distill_chat = "f", synth_chat = "f", score_chat = "f"),
    "created an ID column"
  )
  expect_s3_class(sess, "lloom_session")
  expect_equal(sess$id_col, "id")
  expect_equal(sess$df$id, as.character(1:12))

  df_na <- session_df()
  df_na$text[2] <- NA
  expect_message(
    sess2 <- lloom_session(df_na, "text", "post_id",
                           distill_chat = "f", synth_chat = "f", score_chat = "f"),
    "Dropped 1 row"
  )
  expect_equal(nrow(sess2$df), 11)

  df_dup <- rbind(session_df(), session_df()[1, ])
  expect_error(
    lloom_session(df_dup, "text", "post_id",
                  distill_chat = "f", synth_chat = "f", score_chat = "f"),
    "duplicated"
  )
})

test_that("count_sentences and lloom_suggest_params follow upstream heuristics", {
  cs <- lloomr:::count_sentences
  expect_equal(cs("One. Two! Three?"), 3L)
  expect_equal(cs("No terminal punctuation"), 1L)
  expect_equal(cs("Trailing dots... and more. "), 2L)

  sess <- fake_session()  # 3 sentences per doc
  p <- lloom_suggest_params(sess)
  expect_equal(p$filter_n_quotes, 3)   # ceiling(3 * 0.75) = 3
  expect_equal(p$summ_n_bullets, 2)    # floor(3 * 0.75) = 2
  expect_equal(p$synth_n_concepts, 6)  # floor(20 / 3)
})

test_that("lloom_gen orchestrates distill -> cluster -> synthesize -> review", {
  calls <- character(0)
  cc <- new_concepts(c("A", "B"), c("A?", "B?"))
  assignments <- tibble::tibble(
    post_id = c("p01", "p02"), text = c("t", "t"),
    concept_id = cc$id, concept_name = cc$name,
    concept_prompt = cc$prompt, seed = NA_character_
  )
  local_mocked_bindings(
    distill_filter = function(df, text_col, id_col, chat, ...) {
      calls <<- c(calls, "filter")
      tibble::tibble(post_id = df[[id_col]], text = "quotes")
    },
    distill_summarize = function(df, text_col, id_col, chat, n_bullets, ...) {
      calls <<- c(calls, "summarize")
      expect_equal(n_bullets, 2)
      tibble::tibble(post_id = rep(df[[id_col]], 2), text = "bullet")
    },
    cluster_texts = function(df, text_col, id_col, ...) {
      calls <<- c(calls, "cluster")
      tibble::tibble(post_id = df[[id_col]], text = df[[text_col]], cluster_id = 0L)
    },
    synthesize_concepts = function(cluster_df, text_col, id_col, chat, n_concepts, ...) {
      calls <<- c(calls, "synthesize")
      expect_equal(n_concepts, 6)
      list(concepts = cc, assignments = assignments)
    },
    review_concepts = function(concepts, chat, assignments = NULL, ...) {
      calls <<- c(calls, "review")
      list(concepts = concepts, assignments = assignments,
           removed = character(0), merged = tibble::tibble())
    }
  )
  sess <- fake_session()
  sess <- lloom_gen(sess, verbose = FALSE)

  expect_equal(calls, c("filter", "summarize", "cluster", "synthesize", "review"))
  expect_equal(nrow(sess$concepts), 2)
  expect_equal(nrow(sess$assignments), 2)
  expect_true(all(c("distill_filter", "distill_summarize", "cluster_1",
                    "synthesize_1", "review_1") %in%
                  vapply(sess$history, function(h) h$step, character(1))))
})

test_that("lloom_gen skips the filter when filter_n_quotes <= 1 and samples", {
  calls <- character(0)
  local_mocked_bindings(
    distill_filter = function(...) stop("filter must be skipped"),
    distill_summarize = function(df, text_col, id_col, chat, ...) {
      calls <<- c(calls, "summarize")
      expect_equal(nrow(df), 5)  # sample_n respected
      tibble::tibble(post_id = df[[id_col]], text = "bullet")
    },
    cluster_texts = function(df, text_col, id_col, ...) {
      tibble::tibble(post_id = df[[id_col]], text = df[[text_col]], cluster_id = 0L)
    },
    synthesize_concepts = function(cluster_df, ...) {
      list(concepts = new_concepts("A", "A?"),
           assignments = tibble::tibble())
    },
    review_concepts = function(concepts, chat, assignments = NULL, ...) {
      list(concepts = concepts, assignments = assignments,
           removed = character(0), merged = tibble::tibble())
    }
  )
  sess <- fake_session()
  params <- list(filter_n_quotes = 1, summ_n_bullets = 2, synth_n_concepts = 3)
  sess <- lloom_gen(sess, params = params, sample_n = 5, verbose = FALSE)
  expect_equal(calls, "summarize")
  expect_equal(nrow(sess$df), 12)  # full data untouched
})

test_that("lloom_gen n_synth = 2 re-synthesizes from concepts with shrunken n", {
  synth_inputs <- list()
  synth_ns <- numeric(0)
  cc <- new_concepts(c("A", "B"), c("Is A?", "Is B?"))
  assignments <- tibble::tibble(
    post_id = c("p01", "p02"), text = c("t", "t"),
    concept_id = cc$id, concept_name = cc$name,
    concept_prompt = cc$prompt, seed = NA_character_
  )
  local_mocked_bindings(
    distill_summarize = function(df, text_col, id_col, chat, ...) {
      tibble::tibble(post_id = df[[id_col]], text = "bullet")
    },
    cluster_texts = function(df, text_col, id_col, ...) {
      synth_inputs[[length(synth_inputs) + 1]] <<- df
      tibble::tibble(post_id = df[[id_col]], text = df[[text_col]], cluster_id = 0L)
    },
    synthesize_concepts = function(cluster_df, text_col, id_col, chat, n_concepts, ...) {
      synth_ns <<- c(synth_ns, n_concepts)
      list(concepts = cc, assignments = assignments)
    },
    review_concepts = function(concepts, chat, assignments = NULL, ...) {
      list(concepts = concepts, assignments = assignments,
           removed = character(0), merged = tibble::tibble())
    }
  )
  sess <- fake_session()
  params <- list(filter_n_quotes = 1, summ_n_bullets = 2, synth_n_concepts = 6)
  sess <- lloom_gen(sess, params = params, n_synth = 2, verbose = FALSE)

  expect_equal(synth_ns, c(6, 4))  # floor(6 * 0.75) = 4
  # Second clustering input is "name: prompt" texts from iteration 1
  expect_equal(synth_inputs[[2]]$text, c("A: Is A?", "B: Is B?"))
})

test_that("lloom_score requires active concepts and stores results", {
  sess <- fake_session()
  expect_error(lloom_score(sess), "Run.*lloom_gen")

  sess$concepts <- new_concepts(c("A", "B"), c("A?", "B?"))  # inactive
  expect_error(lloom_score(sess, verbose = FALSE), "No active concepts")

  scored_with <- NULL
  local_mocked_bindings(
    score_concepts = function(df, text_col, id_col, concepts, chat, ...) {
      scored_with <<- concepts
      tibble::tibble(post_id = df[[id_col]], score = 1)
    }
  )
  sess$concepts$active <- c(TRUE, FALSE)
  sess <- lloom_score(sess, verbose = FALSE)
  expect_equal(scored_with$name, "A")  # only active scored
  expect_equal(nrow(lloom_results(sess)), 12)

  sess2 <- lloom_score(sess, score_all = TRUE, verbose = FALSE)
  expect_equal(scored_with$name, c("A", "B"))
  expect_true(all(sess2$concepts$active))
})

test_that("lloom_add_concept and lloom_results behave", {
  sess <- fake_session()
  expect_error(lloom_results(sess), "lloom_score")
  sess <- lloom_add_concept(sess, "Manual Concept", "Is it manual?")
  expect_equal(sess$concepts$name, "Manual Concept")
  expect_true(sess$concepts$active)
  sess <- lloom_add_concept(sess, "Second", "Second?")
  expect_equal(nrow(sess$concepts), 2)
})

test_that("summary and print report steps, time, and cost", {
  sess <- fake_session()
  expect_equal(nrow(summary(sess)), 0)

  sess$history <- list(
    list(step = "distill_summarize", seconds = 2.5,
         usage = data.frame(provider = "OpenAI", model = "m",
                            input = 100, output = 50, price = 0.001)),
    list(step = "cluster_1", seconds = 1.0, usage = NULL)
  )
  s <- summary(sess)
  expect_equal(nrow(s), 2)
  expect_equal(s$input_tokens[1], 100)
  expect_true(is.na(s$price[2]))

  expect_output(print(sess), "12 documents")
  expect_output(print(sess), "Total time")
})

test_that("cost estimators return positive token estimates", {
  local_mocked_bindings(
    model_prices = function(chat) c(input = 1 / 1e6, output = 2 / 1e6)
  )
  sess <- fake_session()
  gen_est <- lloom_estimate_gen_cost(
    sess, params = list(filter_n_quotes = 2, summ_n_bullets = 2, synth_n_concepts = 5)
  )
  expect_equal(gen_est$step, c("distill_filter", "distill_summarize", "synthesize", "review"))
  expect_true(all(gen_est$input_tokens > 0))
  expect_true(all(gen_est$dollars > 0))

  # filter skipped -> zero filter tokens
  gen_est2 <- lloom_estimate_gen_cost(
    sess, params = list(filter_n_quotes = 1, summ_n_bullets = 2, synth_n_concepts = 5)
  )
  expect_equal(gen_est2$input_tokens[1], 0)

  score_est <- lloom_estimate_score_cost(sess, n_concepts = 3, batch_size = 2)
  expect_equal(score_est$output_tokens, 3 * 12 * 100)
  expect_gt(score_est$dollars, 0)

  # Unknown model -> NA dollars, token estimates still present
  local_mocked_bindings(
    model_prices = function(chat) c(input = NA_real_, output = NA_real_)
  )
  est_na <- lloom_estimate_score_cost(sess, n_concepts = 1)
  expect_true(is.na(est_na$dollars))
  expect_gt(est_na$input_tokens, 0)
})

# Live end-to-end test (skipped without OPENAI_API_KEY) =====================

test_that("live: full session pipeline gen -> select -> score on real data", {
  skip_if_no_key()
  df <- data.frame(
    post_id = as.character(1:10),
    text = c(
      "Covid vaccines are safe and effective. Get your booster today.",
      "Vaccination protects your whole community from severe disease.",
      "New study confirms vaccine safety across all age groups.",
      "I got my flu shot and covid booster together. No side effects.",
      "Public health officials urge everyone to stay up to date on shots.",
      "The mainstream media hides the truth and pushes one narrative.",
      "Every news channel runs identical headlines. That is coordination.",
      "Journalists protect the powerful instead of holding them to account.",
      "Cable news is pure propaganda at this point. Think for yourself.",
      "The press buried the story because it hurt their preferred side."
    )
  )
  chat <- live_chat()
  sess <- lloom_session(df, "text", "post_id",
                        distill_chat = chat, synth_chat = chat, score_chat = chat,
                        embed_fn = function(t) ll_embed(t, model = "text-embedding-3-small"))

  est <- lloom_estimate_gen_cost(sess)
  expect_true(all(est$input_tokens >= 0))

  sess <- lloom_gen(
    sess,
    params = list(filter_n_quotes = 1, summ_n_bullets = "1-2", synth_n_concepts = 2),
    max_concepts = 2, verbose = FALSE
  )
  expect_gte(nrow(sess$concepts), 1)
  expect_gte(sum(sess$concepts$active), 1)

  sess <- lloom_score(sess, batch_size = 5, verbose = FALSE)
  res <- lloom_results(sess)
  expect_equal(nrow(res), 10 * sum(sess$concepts$active))
  expect_true(all(res$score %in% c(0, 0.25, 0.5, 0.75, 1)))

  s <- summary(sess)
  expect_gte(nrow(s), 4)
  expect_gt(sum(s$input_tokens, na.rm = TRUE), 0)
})
