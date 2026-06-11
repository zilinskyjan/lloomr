# Distill documents to salient quotes

For each document, asks the LLM to extract `n_quotes` quotes copied
verbatim from the text (the optional `seed` steers which quotes count as
relevant). This is the first, optional step of the LLooM pipeline,
typically used for long documents; short texts (e.g. social media posts)
can skip straight to
[`distill_summarize()`](https://zilinskyjan.github.io/lloomr/reference/distill_summarize.md).

## Usage

``` r
distill_filter(
  df,
  text_col,
  id_col,
  chat,
  n_quotes = 3,
  seed = NULL,
  prompt_template = NULL,
  max_active = 10,
  rpm = 500
)
```

## Arguments

- df:

  Data frame of documents.

- text_col, id_col:

  Column names (strings) for document text and IDs.

- chat:

  An ellmer chat object used for the LLM calls.

- n_quotes:

  Number of quotes to extract per document. Default 3.

- seed:

  Optional seed term to steer extraction (e.g. "media distrust").

- prompt_template:

  Optional custom template; must contain the fields required by
  `validate_prompt("distill_filter", ...)`.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A tibble with columns `id_col` and `text_col`, where `text_col` now
holds the extracted quotes (newline-separated), one row per document.
Documents whose query failed are dropped (with a warning). Token/cost
usage is attached as attribute `"usage"`.

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
quotes <- distill_filter(df, "text", "doc_id", chat, n_quotes = 2)
} # }
```
