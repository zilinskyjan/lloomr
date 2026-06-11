test_that("new_concepts builds a valid vectorized concept tibble", {
  cc <- new_concepts(
    name = c("Economic Anxiety", "Distrust of Media"),
    prompt = c("Does the text express economic concern?",
               "Does the text express distrust of media?")
  )
  expect_s3_class(cc, "lloom_concepts")
  expect_equal(nrow(cc), 2)
  expect_named(cc, c("id", "name", "prompt", "example_ids", "active", "summary", "seed"))
  expect_length(unique(cc$id), 2)
  expect_false(any(cc$active))
  expect_true(all(is.na(cc$summary)))
  expect_identical(cc$example_ids, list(character(0), character(0)))
  expect_invisible(validate_concepts(cc))
})

test_that("new_concepts handles example_ids for single and multiple concepts", {
  c1 <- new_concepts("A", "B?", example_ids = c("1", "2", "2"))
  expect_identical(c1$example_ids, list(c("1", "2")))  # deduped

  c2 <- new_concepts(c("A", "B"), c("A?", "B?"),
                     example_ids = list(c("1"), c("2", "3")))
  expect_identical(c2$example_ids, list("1", c("2", "3")))

  # numeric IDs are coerced to character
  c3 <- new_concepts("A", "A?", example_ids = list(c(1, 2)))
  expect_identical(c3$example_ids, list(c("1", "2")))

  expect_error(new_concepts(c("A", "B"), c("A?", "B?"), example_ids = list("1")))
})

test_that("validate_concepts catches structural problems", {
  cc <- new_concepts("A", "A?")
  bad <- cc[, setdiff(names(cc), "prompt")]
  expect_error(validate_concepts(bad), "missing column")

  dup <- rbind(cc, cc)
  expect_error(validate_concepts(dup), "duplicated")

  flat <- as.data.frame(cc[, setdiff(names(cc), "example_ids")])
  flat$example_ids <- "not-a-list"
  expect_error(validate_concepts(flat), "list column")
})

test_that("concepts_to_text formats the review-prompt block", {
  cc <- new_concepts(c("A", "B"), c("Is it A?", "Is it B?"))
  txt <- lloomr:::concepts_to_text(cc)
  expect_equal(txt, "- Name: A, Prompt: Is it A?\n- Name: B, Prompt: Is it B?")
})
