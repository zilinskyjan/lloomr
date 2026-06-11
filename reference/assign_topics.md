# Assign each document to exactly one topic

Forced-choice classification of documents into a fixed topic set
(typically the concepts kept after
[`review_concepts()`](https://zilinskyjan.github.io/lloomr/reference/review_concepts.md)
/
[`refine_concepts()`](https://zilinskyjan.github.io/lloomr/reference/refine_concepts.md),
possibly edited by the user). Unlike
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md),
which rates every (document, concept) pair independently (multi-label),
this returns exactly one topic per document. The topic label is
constrained to the provided set via the structured-output schema, so the
model cannot invent labels.

## Usage

``` r
assign_topics(
  df,
  text_col,
  id_col,
  topics,
  chat,
  allow_other = TRUE,
  other_label = "Other",
  batch_size = 5,
  max_active = 10,
  rpm = 500
)
```

## Arguments

- df:

  Data frame of documents.

- text_col, id_col:

  Column names (strings) for document text and IDs.

- topics:

  The fixed topic set: either a concept tibble (names and prompts are
  shown to the model) or a character vector of topic names.

- chat:

  An ellmer chat object.

- allow_other:

  If `TRUE` (default), adds an `other_label` option for documents
  fitting none of the topics; with `FALSE` the model must force every
  document into one of the topics.

- other_label:

  Label used for non-fitting documents. Default `"Other"`.

- batch_size:

  Documents per LLM call. Default 5.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A tibble with one row per document: `id_col`, `text`, `topic`,
`rationale`. Documents missing from LLM responses get `topic = NA` (with
a warning). Token/cost usage is attached as attribute `"usage"`.

## Details

This is an lloomr extension; the upstream Python package has no
single-label operator.

## Examples

``` r
if (FALSE) { # \dontrun{
topics <- new_concepts(
  name = c("Vaccine Promotion", "Media Distrust"),
  prompt = c("Promotes vaccination?", "Expresses distrust of media?")
)
assignments <- assign_topics(df, "text", "post_id", topics, chat)
table(assignments$topic)
} # }
```
