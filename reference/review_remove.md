# Remove low-quality concepts

Asks the LLM which concepts to drop: without a `seed`, those too narrow
or too broad; with a `seed`, those unrelated to the seed topic.

## Usage

``` r
review_remove(concepts, chat, seed = NULL, max_active = 10, rpm = 500)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- chat:

  An ellmer chat object.

- seed:

  Optional seed term; switches to the seeded variant prompt.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A list: `concepts` (kept rows) and `removed` (character vector of
removed names). If the query fails, all concepts are kept.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- review_remove(concepts, chat)
res$removed
} # }
```
