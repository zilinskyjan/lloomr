# Helpers for live API integration tests.
# Live tests run only when OPENAI_API_KEY is set; they use gpt-4o-mini /
# text-embedding-3-small on tiny inputs (cost: fractions of a cent).
# They are inherently non-deterministic, so they are also skipped on CRAN
# and whenever LLOOMR_SKIP_LIVE is set (set it for R CMD check runs to
# keep the check reproducible).

skip_if_no_key <- function() {
  testthat::skip_on_cran()
  testthat::skip_if(
    nzchar(Sys.getenv("LLOOMR_SKIP_LIVE")),
    "LLOOMR_SKIP_LIVE set; skipping live API test"
  )
  testthat::skip_if(
    !nzchar(Sys.getenv("OPENAI_API_KEY")),
    "OPENAI_API_KEY not set; skipping live API test"
  )
}

live_chat <- function() {
  ellmer::chat_openai(model = "gpt-4o-mini", echo = "none")
}
