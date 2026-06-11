# Mocked tests for the LLM layer (no network) ===============================

test_that("ll_query returns one result per prompt and normalizes failures", {
  fake_results <- list(
    list(bullets = list("a", "b")),
    simpleError("boom"),       # a failed request surfaced as a condition
    NULL,                      # a failed request surfaced as NULL
    list(bullets = list("c"))
  )
  local_mocked_bindings(
    ll_parallel_impl = function(chat, prompts, type, max_active, rpm) {
      expect_length(prompts, 4)
      expect_true(is.list(prompts))
      fake_results
    }
  )
  expect_warning(
    res <- ll_query("fake-chat", paste("prompt", 1:4), lloom_type("distill_summarize")),
    "2/4"
  )
  expect_length(res, 4)
  expect_equal(res[[1]]$bullets, list("a", "b"))
  expect_null(res[[2]])
  expect_null(res[[3]])
  expect_equal(res[[4]]$bullets, list("c"))
})

test_that("ll_query accepts character vectors and lists of prompts", {
  local_mocked_bindings(
    ll_parallel_impl = function(chat, prompts, type, max_active, rpm) {
      lapply(prompts, function(p) list(ok = p))
    }
  )
  res_chr <- ll_query("c", c("x", "y"), lloom_type("distill_summarize"))
  res_lst <- ll_query("c", list("x", "y"), lloom_type("distill_summarize"))
  expect_equal(res_chr, res_lst, ignore_attr = TRUE)
  expect_error(ll_query("c", character(0), lloom_type("distill_summarize")))
})

test_that("usage_delta subtracts a prior snapshot correctly", {
  ud <- lloomr:::usage_delta
  before <- data.frame(
    provider = "OpenAI", model = "gpt-4o-mini",
    input = 100, output = 50, price = 0.01
  )
  after <- data.frame(
    provider = c("OpenAI", "OpenAI"),
    model = c("gpt-4o-mini", "gpt-4o"),
    input = c(150, 200), output = c(70, 80), price = c(0.015, 0.02)
  )
  delta <- ud(before, after)
  mini <- delta[delta$model == "gpt-4o-mini", ]
  big <- delta[delta$model == "gpt-4o", ]
  expect_equal(mini$input, 50)    # 150 - 100
  expect_equal(mini$output, 20)   # 70 - 50
  expect_equal(big$input, 200)    # model not in `before`: full amount
  expect_equal(big$output, 80)

  # No snapshot before -> return after as-is; no usable after -> NULL
  expect_equal(ud(NULL, after), after)
  expect_null(ud(before, NULL))
  # No new tokens -> zero rows
  expect_equal(nrow(ud(before, before)), 0)
})

test_that("combine_usage sums across calls by provider/model", {
  cu <- lloomr:::combine_usage
  u1 <- data.frame(provider = "OpenAI", model = "gpt-4o-mini", input = 10, output = 5)
  u2 <- data.frame(provider = "OpenAI", model = "gpt-4o-mini", input = 7, output = 3)
  u3 <- data.frame(provider = "OpenAI", model = "gpt-4o", input = 1, output = 1)
  out <- cu(list(u1, u2, u3, NULL))
  expect_equal(nrow(out), 2)
  mini <- out[out$model == "gpt-4o-mini", ]
  expect_equal(mini$input, 17)
  expect_equal(mini$output, 8)
  expect_null(cu(list(NULL, NULL)))
})

test_that("ll_embed batches requests and assembles the matrix in order", {
  calls <- list()
  local_mocked_bindings(
    ll_embed_request = function(texts, model, api_key, base_url, dimensions = NULL) {
      calls[[length(calls) + 1]] <<- texts
      # Deterministic fake embedding: encode text length
      lapply(texts, function(t) c(nchar(t), 1, 2))
    }
  )
  texts <- c("aa", "bbbb", "c\nc", "dddddd", "e")
  m <- ll_embed(texts, batch_size = 2, api_key = "fake-key")

  expect_equal(dim(m), c(5, 3))
  expect_length(calls, 3)                       # 5 texts / batch of 2 -> 3 calls
  expect_equal(lengths(calls), c(2, 2, 1))
  expect_equal(calls[[2]][1], "c c")            # newline replaced with space
  expect_equal(m[, 1], nchar(gsub("\n", " ", texts)))  # row order preserved
})

test_that("ll_embed validates inputs and result counts", {
  expect_error(ll_embed(character(0), api_key = "k"))
  expect_error(ll_embed("x", api_key = ""), "OPENAI_API_KEY")

  local_mocked_bindings(
    ll_embed_request = function(texts, model, api_key, base_url, dimensions = NULL) {
      list(c(1, 2))  # wrong count: 1 vector for 2 texts
    }
  )
  expect_error(ll_embed(c("a", "b"), api_key = "k"), "2 texts")
})

# Live smoke tests (skipped without OPENAI_API_KEY) =========================

test_that("live: ll_query returns structured bullets and usage", {
  skip_if_no_key()
  prompts <- vapply(
    c("The economy grew rapidly last quarter.",
      "Voters are skeptical of new media."),
    function(ex) render_prompt(
      lloom_prompt("distill_summarize"),
      list(ex = ex, seeding_phrase = "", n_bullets = 2, n_words = "3-5")
    ),
    character(1)
  )
  res <- ll_query(live_chat(), prompts, lloom_type("distill_summarize"))

  expect_length(res, 2)
  for (r in res) {
    expect_true(is.list(r$bullets))
    expect_gte(length(r$bullets), 1)
    expect_true(all(vapply(r$bullets, is.character, logical(1))))
  }
  usage <- attr(res, "usage")
  expect_s3_class(usage, "data.frame")
  expect_gt(sum(usage$input), 0)
})

test_that("live: ll_embed returns a numeric matrix of consistent dimension", {
  skip_if_no_key()
  texts <- c("politics and elections", "sports scores", "politics and voting")
  m <- ll_embed(texts, model = "text-embedding-3-small")

  expect_true(is.matrix(m), is.numeric(m))
  expect_equal(nrow(m), 3)
  expect_gt(ncol(m), 100)
  # Sanity: related texts (1, 3) should be more similar than unrelated (1, 2)
  cos <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
  expect_gt(cos(m[1, ], m[3, ]), cos(m[1, ], m[2, ]))
})
