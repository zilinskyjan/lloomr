# Merge overlapping concepts

Asks the LLM for pairs of similar/overlapping concepts and replaces each
pair with a newly named merged concept (with the union of the originals'
exemplar IDs). Only pairs whose two originals both exist (and were not
already consumed by an earlier merge) are applied.

## Usage

``` r
review_merge(concepts, chat, max_active = 10, rpm = 500)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- chat:

  An ellmer chat object.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A list: `concepts` (with merged rows replacing originals) and `merged`
(tibble with columns `original_1`, `original_2`, `merged_name`,
`merged_id`; zero rows if nothing merged).

## Examples

``` r
if (FALSE) { # \dontrun{
res <- review_merge(concepts, chat)
res$merged  # which pairs were combined, and into what
} # }
```
