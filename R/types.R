# ellmer structured-output type specifications.
#
# One schema per LLM operator, matching the JSON shapes that upstream
# prompts.py instructs the model to emit. With structured output the model
# is constrained to these shapes at the API level, replacing upstream's
# trim-and-parse approach (json_load) as the primary parsing path.

#' Get the structured-output schema for a LLooM step
#'
#' Returns the `ellmer` type specification describing the response shape for
#' a pipeline step. Used internally with
#' [ellmer::parallel_chat_structured()]; exported so users supplying custom
#' prompts can reuse or inspect the expected output shape.
#'
#' @param step One of `"distill_filter"`, `"distill_summarize"`,
#'   `"synthesize"`, `"review_remove"`, `"review_remove_seed"`,
#'   `"review_merge"`, `"review_select"`, `"score"`, `"score_highlight"`,
#'   `"summarize_concept"`, `"auto_eval"`.
#' @return An `ellmer` type object.
#' @export
#' @examples
#' lloom_type("synthesize")
lloom_type <- function(step) {
  types <- list(
    distill_filter = function() ellmer::type_object(
      relevant_quotes = ellmer::type_array(
        ellmer::type_string(),
        "Quotes copied exactly from the example"
      )
    ),
    distill_summarize = function() ellmer::type_object(
      bullets = ellmer::type_array(
        ellmer::type_string(),
        "Bullet-point phrases summarizing the example"
      )
    ),
    synthesize = function() ellmer::type_object(
      patterns = ellmer::type_array(
        ellmer::type_object(
          name = ellmer::type_string("2-4 word name for the pattern"),
          prompt = ellmer::type_string(
            "1-sentence yes/no question to determine whether the pattern applies to a new text example"
          ),
          example_ids = ellmer::type_array(
            ellmer::type_string(),
            "IDs of 1-2 examples that best exemplify the pattern"
          )
        )
      )
    ),
    review_remove = function() ellmer::type_object(
      remove = ellmer::type_array(
        ellmer::type_string(),
        "Names of themes to remove (empty if none)"
      )
    ),
    review_merge = function() ellmer::type_object(
      merge = ellmer::type_array(
        ellmer::type_object(
          original_themes = ellmer::type_array(
            ellmer::type_string(),
            "The pair of original theme names to merge"
          ),
          merged_theme_name = ellmer::type_string("New 2-3 word name"),
          merged_theme_prompt = ellmer::type_string("New 1-sentence prompt")
        )
      )
    ),
    review_select = function() ellmer::type_object(
      selected = ellmer::type_array(
        ellmer::type_string(),
        "Names of the selected themes"
      )
    ),
    score = function() ellmer::type_object(
      pattern_results = ellmer::type_array(
        ellmer::type_object(
          example_id = ellmer::type_string(),
          rationale = ellmer::type_string("1-sentence rationale"),
          answer = ellmer::type_enum(
            c("A", "B", "C", "D", "E"),
            "A: Strongly agree ... E: Strongly disagree"
          )
        )
      )
    ),
    score_highlight = function() ellmer::type_object(
      pattern_results = ellmer::type_array(
        ellmer::type_object(
          example_id = ellmer::type_string(),
          rationale = ellmer::type_string("1-sentence rationale"),
          answer = ellmer::type_enum(
            c("A", "B", "C", "D", "E"),
            "A: Strongly agree ... E: Strongly disagree"
          ),
          quote = ellmer::type_string(
            "1-sentence quote copied exactly from the example",
            required = FALSE
          )
        )
      )
    ),
    summarize_concept = function() ellmer::type_object(
      summary = ellmer::type_string("Brief executive summary of the theme")
    ),
    auto_eval = function() ellmer::type_object(
      concept_matches = ellmer::type_array(
        ellmer::type_object(
          concept_id = ellmer::type_string(),
          item_id = ellmer::type_string("Matching item ID, or NONE"),
          rationale = ellmer::type_string("1-sentence rationale", required = FALSE)
        )
      )
    )
  )
  # The seeded variant shares the unseeded response shape
  types$review_remove_seed <- types$review_remove

  if (!step %in% names(types)) {
    cli::cli_abort(c(
      "Unknown step {.val {step}}.",
      "i" = "Available steps: {.val {names(types)}}"
    ))
  }
  types[[step]]()
}
