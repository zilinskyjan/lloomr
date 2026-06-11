# Score documents against concepts

The deductive step of LLooM: every document is rated against every
concept's inclusion criterion on a 5-point scale (A "strongly agree" ...
E "strongly disagree", mapped to 1, 0.75, 0.5, 0.25, 0 by
[`letter_to_score()`](https://zilinskyjan.github.io/lloomr/reference/letter_to_score.md)).
Documents are scored in batches per concept, and all concept-batches run
concurrently in a single
[`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md)
call.

## Usage

``` r
score_concepts(
  df,
  text_col,
  id_col,
  concepts,
  chat,
  batch_size = 5,
  get_highlights = FALSE,
  max_active = 10,
  rpm = 500
)
```

## Arguments

- df:

  Data frame of documents to score (typically the full dataset, even if
  concepts were generated from a sample).

- text_col, id_col:

  Column names (strings) for document text and IDs.

- concepts:

  Concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).
  All rows are scored; filter to `active` concepts first if that is what
  you want (the session pipeline does this automatically).

- chat:

  An ellmer chat object (high-volume step; a cheap model like
  gpt-4o-mini is the upstream default).

- batch_size:

  Documents per LLM call. Default 5 (upstream default; upstream's
  session pipeline uses 1).

- get_highlights:

  If `TRUE`, also ask for a supporting quote from each example (stored
  in `highlight`). Default `FALSE`.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A tibble with one row per (document, concept) pair: `id_col`, `text`,
`concept_id`, `concept_name`, `concept_prompt`, `score`, `rationale`,
`highlight`, `concept_seed`. Token/cost usage is attached as attribute
`"usage"`.

## Details

Every (document, concept) pair is guaranteed to appear exactly once in
the output: pairs missing from LLM responses (failed queries, skipped
IDs) are backfilled with score 0 and empty rationale, as upstream.

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
concepts <- new_concepts(
  "Vaccine Promotion",
  "Does the text promote or encourage vaccination?"
)
score_df <- score_concepts(df, "text", "doc_id", concepts, chat,
                           get_highlights = TRUE)
# Prevalence: fraction of documents matching each concept
aggregate(score >= 1 ~ concept_name, data = score_df, FUN = mean)

# The result is a plain tibble; save it like any data frame:
readr::write_csv(score_df, "scores.csv")
} # }
```
