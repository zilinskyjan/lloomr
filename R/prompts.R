# Prompt templates for all LLooM operators.
#
# Translated near-verbatim from upstream text_lloom/prompts.py. Python's
# str.format() and glue share the same placeholder syntax ({var} for
# interpolation, {{ }} for literal braces), so the templates port directly.
# The JSON format instructions are kept even though lloomr enforces output
# shape via ellmer structured output: they help weaker models comply and keep
# the prompts comparable to the original paper.
#
# Wording deviations from upstream: the distill prompts use declarative
# instructions ("Extract ...", "Summarize ...") instead of "Please extract /
# Please summarize", and "ChatGPT PROMPT" is "PROMPT" (provider-agnostic).

# Distill - Filter ========================
filter_prompt <- "
I have the following TEXT EXAMPLE:
{ex}

Extract {n_quotes} QUOTES exactly copied from this EXAMPLE that are {seeding_phrase}. Respond ONLY with a valid JSON in the following format:
{{
    \"relevant_quotes\": [ \"<QUOTE_1>\", \"<QUOTE_2>\", ... ]
}}
"

# Distill - Summarize ========================
summarize_prompt <- "
I have the following TEXT EXAMPLE:
{ex}

Summarize the main point of this EXAMPLE {seeding_phrase} into {n_bullets} bullet points, where each bullet point is a {n_words} word phrase. Respond ONLY with a valid JSON in the following format:
{{
    \"bullets\": [ \"<BULLET_1>\", \"<BULLET_2>\", ... ]
}}
"

# Synthesize ========================
synthesize_prompt <- "
I have this set of bullet point summaries of text examples:
{examples}

Please write a summary of {n_concepts_phrase} for these examples. {seeding_phrase} For each high-level pattern, write a 2-4 word NAME for the pattern and an associated 1-sentence PROMPT that could take in a new text example and determine whether the relevant pattern applies. Also include 1-2 example_ids for items that BEST exemplify the pattern. Please respond ONLY with a valid JSON in the following format:
{{
    \"patterns\": [
        {{\"name\": \"<PATTERN_NAME_1>\", \"prompt\": \"<PATTERN_PROMPT_1>\", \"example_ids\": [\"<EXAMPLE_ID_1>\", \"<EXAMPLE_ID_2>\"]}},
        {{\"name\": \"<PATTERN_NAME_2>\", \"prompt\": \"<PATTERN_PROMPT_2>\", \"example_ids\": [\"<EXAMPLE_ID_1>\", \"<EXAMPLE_ID_2>\"]}}
    ]
}}
"

# Review ========================
review_remove_prompt <- "
I have this set of themes generated from text examples:
{concepts}

Please identify any themes that should be REMOVED because they are either:
(1) Too specific/narrow and would only describe a few examples, or
(2) Too generic/broad and would describe nearly all examples.
If there no such themes, please leave the list empty.
Please respond ONLY with a valid JSON in the following format:

{{
    \"remove\": [
        \"<THEME_NAME_5>\",
        \"<THEME_NAME_6>\"
    ]
}}
"

review_remove_prompt_seed <- "
I have this dict of CONCEPTS (keys) and their corresponding inclusion criteria (values), as follows:
{concepts}

I have the following THEME:
{seed}

Please identify any CONCEPTS that DO NOT relate to the THEME and that should be removed. If there no such concepts, please leave the list empty.
Please respond ONLY with a valid JSON in the following format:

{{
    \"remove\": [
        \"<CONCEPT_NAME_5>\",
        \"<CONCEPT_NAME_6>\"
    ]
}}
"

review_merge_prompt <- "
I have this set of themes generated from text examples:
{concepts}

Please identify any PAIRS of themes that are similar or overlapping that should be MERGED together.
Please respond ONLY with a valid JSON in the following format with the original themes and a new name and prompt for the merged theme. Do NOT simply combine the prior theme names or prompts, but come up with a new 2-3 word name and 1-sentence prompt. If there no similar themes, please leave the list empty.

{{
    \"merge\": [
        {{
            \"original_themes\": [\"<THEME_NAME_A>\", \"<THEME_NAME_B>\"],
            \"merged_theme_name\": \"<THEME_NAME_AB>\",
            \"merged_theme_prompt\": \"<THEME_PROMPT_AB>\"
        }},
        {{
            \"original_themes\": [\"<THEME_NAME_C>\", \"<THEME_NAME_D>\"],
            \"merged_theme_name\": \"<THEME_NAME_CD>\",
            \"merged_theme_prompt\": \"<THEME_PROMPT_CD>\"
        }}
    ]
}}
"

review_select_prompt <- "
I have this set of themes generated from text examples:
{concepts}

Please select AT MOST {max_concepts} themes to include in the final set of themes. These themes should be the highest quality themes in the set: (1) NOT too generic or vague (should not describe most examples), (2) NOT too specific (should not only describe a small set of examples), and (3) NOT overlapping with other selected themes (they should capture a range of different patterns).
Please respond ONLY with a valid JSON in the following format:

{{
    \"selected\": [
        \"<THEME_NAME_1>\",
        \"<THEME_NAME_2>\"
    ]
}}
"

# Score ========================
score_no_highlight_prompt <- "
CONTEXT:
    I have the following text examples in a JSON:
    {examples_json}

    I also have a pattern named {concept_name} with the following PROMPT:
    {concept_prompt}

TASK:
    For each example, please evaluate the PROMPT by generating a 1-sentence RATIONALE of your thought process and providing a resulting ANSWER of ONE of the following multiple-choice options, including just the letter:
    - A: Strongly agree
    - B: Agree
    - C: Neither agree nor disagree
    - D: Disagree
    - E: Strongly disagree
    Respond with ONLY a JSON with the following format, escaping any quotes within strings with a backslash:
    {{
        \"pattern_results\": [
            {{
                \"example_id\": \"<example_id>\",
                \"rationale\": \"<rationale>\",
                \"answer\": \"<answer>\"
            }}
        ]
    }}
"

score_highlight_prompt <- "
CONTEXT:
    I have the following text examples in a JSON:
    {examples_json}

    I also have a pattern named {concept_name} with the following PROMPT:
    {concept_prompt}

TASK:
    For each example, please evaluate the PROMPT by generating a 1-sentence RATIONALE of your thought process and providing a resulting ANSWER of ONE of the following multiple-choice options, including just the letter:
    - A: Strongly agree
    - B: Agree
    - C: Neither agree nor disagree
    - D: Disagree
    - E: Strongly disagree
    Please also include one 1-sentence QUOTE exactly copied from the example that illustrates this pattern.
    Respond with ONLY a JSON with the following format, escaping any quotes within strings with a backslash:
    {{
        \"pattern_results\": [
            {{
                \"example_id\": \"<example_id>\",
                \"rationale\": \"<rationale>\",
                \"answer\": \"<answer>\",
                \"quote\": \"<quote>\"
            }}
        ]
    }}
"

# Assign Topic (lloomr extension, not in upstream) ========================
# Forced-choice single-label classification into a fixed topic set.
assign_topic_prompt <- "
CONTEXT:
    I have the following text examples in a JSON:
    {examples_json}

    I also have this fixed set of TOPICS:
    {topics}

TASK:
    For each example, please assign exactly ONE TOPIC from the list above that best describes the example's primary focus, and generate a 1-sentence RATIONALE for your choice. Each example must receive exactly one topic. Do NOT invent new topics.{other_clause}
    Respond with ONLY a JSON in the following format:
    {{
        \"assignments\": [
            {{
                \"example_id\": \"<example_id>\",
                \"rationale\": \"<rationale>\",
                \"topic\": \"<topic>\"
            }}
        ]
    }}
"

# Summarize Concept ========================
summarize_concept_prompt <- "
Please write a BRIEF {summary_length} executive summary of the theme \"{concept_name}\" as it appears in the following examples.
{examples}

DO NOT write the summary as a third party using terms like \"the text examples\" or \"they discuss\", but write the summary from the perspective of the text authors making the points directly.
Please respond ONLY with a valid JSON in the following format:
{{
    \"summary\": \"<SUMMARY>\"
}}
"

# Auto-eval ========================
concept_auto_eval_prompt <- "
I have this set of CONCEPTS:
{concepts}

I have this set of TEXTS:
{items}

Please match at most ONE TEXT to each CONCEPT. To perform a match, the text must EXACTLY match the meaning of the concept. Do NOT match the same TEXT to multiple CONCEPTS.

Here are examples of VALID matches:
- Global Diplomacy, International Relations; rationale: \"The text is about diplomacy between countries.\"
- Statistical Data, Quantitative Evidence; rationale: \"The text is about data and quantitative measures.\"
- Policy and Regulation, Policy issues and legislation; rationale: \"The text is about policy, laws, and legislation.\"

Here are examples of INVALID matches:
- Reputation Impact, Immigration
- Environment, Politics and Law
- Interdisciplinary Politics, Economy

If there are no valid matches, please EXCLUDE the concept from the list. Please provide a 1-sentence RATIONALE for your decision for any matches.
Please respond with a list of each concept and either the item it matches or NONE if no item matches in this format:
{{
    \"concept_matches\": [
        {{
            \"concept_id\": \"<concept_id_number>\",
            \"item_id\": \"<item_id_number or NONE>\",
            \"rationale\": \"<rationale for match>\"
        }}
    ]
}}
"

# Registry ========================

#' All LLooM prompt templates, keyed by step name
#' @noRd
.lloom_prompts <- list(
  distill_filter     = filter_prompt,
  distill_summarize  = summarize_prompt,
  synthesize         = synthesize_prompt,
  review_remove      = review_remove_prompt,
  review_remove_seed = review_remove_prompt_seed,
  review_merge       = review_merge_prompt,
  review_select      = review_select_prompt,
  score              = score_no_highlight_prompt,
  score_highlight    = score_highlight_prompt,
  assign_topic       = assign_topic_prompt,
  summarize_concept  = summarize_concept_prompt,
  auto_eval          = concept_auto_eval_prompt
)

#' Required template fields for each step (used by validate_prompt)
#' @noRd
.lloom_prompt_reqs <- list(
  distill_filter     = c("ex", "n_quotes", "seeding_phrase"),
  distill_summarize  = c("ex", "n_bullets", "seeding_phrase", "n_words"),
  synthesize         = c("examples", "n_concepts_phrase", "seeding_phrase"),
  review_remove      = c("concepts"),
  review_remove_seed = c("concepts", "seed"),
  review_merge       = c("concepts"),
  review_select      = c("concepts", "max_concepts"),
  score              = c("examples_json", "concept_name", "concept_prompt"),
  score_highlight    = c("examples_json", "concept_name", "concept_prompt"),
  assign_topic       = c("examples_json", "topics", "other_clause"),
  summarize_concept  = c("summary_length", "concept_name", "examples"),
  auto_eval          = c("concepts", "items")
)

#' Get the default prompt template for a LLooM step
#'
#' Returns the prompt template used by a given pipeline step. Templates use
#' `glue`-style placeholders (e.g. `{ex}`, `{n_quotes}`); customized versions
#' can be passed back to the corresponding operator via its `prompt_template`
#' argument after checking them with [validate_prompt()].
#'
#' @param step One of `r paste0('"', names(.lloom_prompts), '"', collapse = ", ")`.
#' @return A length-1 character template.
#' @export
#' @examples
#' cat(lloom_prompt("distill_summarize"))
lloom_prompt <- function(step) {
  if (!step %in% names(.lloom_prompts)) {
    cli::cli_abort(c(
      "Unknown step {.val {step}}.",
      "i" = "Available steps: {.val {names(.lloom_prompts)}}"
    ))
  }
  .lloom_prompts[[step]]
}

#' Validate a custom prompt template for a LLooM step
#'
#' Checks that a custom template contains all placeholder fields the step's
#' operator will interpolate (mirrors `validate_prompt()` in upstream
#' `workbench.py`). Throws an error listing any missing fields.
#'
#' @param step Step name (see [lloom_prompt()]).
#' @param prompt Custom template string.
#' @return Invisibly, `prompt` (so it can be piped onward).
#' @export
#' @examples
#' # The default template always validates
#' validate_prompt("distill_summarize", lloom_prompt("distill_summarize"))
#'
#' # A custom template missing required fields errors
#' try(validate_prompt("distill_summarize", "Summarize {ex} please."))
validate_prompt <- function(step, prompt) {
  if (!step %in% names(.lloom_prompt_reqs)) {
    cli::cli_abort(c(
      "Unknown step {.val {step}}.",
      "i" = "Available steps: {.val {names(.lloom_prompt_reqs)}}"
    ))
  }
  reqs <- .lloom_prompt_reqs[[step]]
  present <- vapply(
    reqs,
    function(req) grepl(paste0("{", req, "}"), prompt, fixed = TRUE),
    logical(1)
  )
  if (!all(present)) {
    missing_fields <- reqs[!present]
    cli::cli_abort(c(
      "Custom prompt for {.val {step}} is missing required template field{?s}: {.val {missing_fields}}.",
      "i" = "All required fields: {.val {reqs}}.",
      "i" = "See {.code lloom_prompt(\"{step}\")} for the default template."
    ))
  }
  invisible(prompt)
}

#' Render a prompt template with arguments
#'
#' Interpolates a `glue`-style template with values from a named list.
#' Values inserted into the template are *not* re-interpolated, so JSON or
#' braces inside argument values are safe.
#'
#' @param template Template string with `{placeholder}` fields.
#' @param args Named list of values to interpolate.
#' @return A length-1 character string.
#' @export
#' @examples
#' render_prompt("Summarize {ex} in {n} words.", list(ex = "some text", n = 5))
render_prompt <- function(template, args) {
  stopifnot(is.character(template), length(template) == 1)
  out <- glue::glue_data(args, template, .trim = FALSE)
  unclass(out)
}
