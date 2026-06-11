# Summarize a concept from its matching examples

Generates a brief executive summary of one concept from the examples
that matched it (mirrors upstream `summarize_concept()`). By default it
summarizes the highlight quotes, so scoring should have been run with
`get_highlights = TRUE`; set `examples_col = "text"` to summarize the
full matched documents instead.

## Usage

``` r
summarize_concept(
  score_df,
  concept_id,
  chat,
  threshold = 1,
  summary_length = "15-20 word",
  examples_col = "highlight",
  max_active = 10,
  rpm = 500
)
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md).

- concept_id:

  ID of the concept to summarize.

- chat:

  An ellmer chat object.

- threshold:

  Minimum score counting as a match. Default 1 (upstream).

- summary_length:

  Length instruction. Default `"15-20 word"`.

- examples_col:

  Column with the example texts to summarize. Default `"highlight"`.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A summary string, or `NA_character_` if the concept has no matches (or
the query fails).

## Examples

``` r
if (FALSE) { # \dontrun{
summarize_concept(score_df, concepts$id[1], chat)
} # }
```
