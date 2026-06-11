# Distill documents to bullet-point summaries

For each document (or its quotes from
[`distill_filter()`](https://zilinskyjan.github.io/lloomr/reference/distill_filter.md)),
asks the LLM for `n_bullets` short bullet-point summaries. Bullets are
the unit that gets clustered and synthesized into concepts downstream.

## Usage

``` r
distill_summarize(
  df,
  text_col,
  id_col,
  chat,
  n_bullets = "2-4",
  n_words_per_bullet = "5-8",
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

- n_bullets:

  Number of bullets per document; a number or a range string like
  `"2-4"` (upstream default).

- n_words_per_bullet:

  Length of each bullet; a number or range string like `"5-8"` (upstream
  default).

- seed:

  Optional seed term to steer extraction (e.g. "media distrust").

- prompt_template:

  Optional custom template; must contain the fields required by
  `validate_prompt("distill_filter", ...)`.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A tibble with columns `id_col` and `text_col`, **one row per bullet**
(document IDs repeat). Documents whose query failed are dropped (with a
warning). Token/cost usage is attached as attribute `"usage"`.

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
bullets <- distill_summarize(df, "text", "doc_id", chat, n_bullets = "1-2",
                             seed = "media trust")
} # }
```
