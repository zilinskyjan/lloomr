# Select the best concepts (sets `active`)

Asks the LLM to pick at most `max_concepts` high-quality,
non-overlapping concepts, and marks those rows `active = TRUE`
(everything else `FALSE`). If the LLM selects nothing usable, a random
sample is activated instead, with a warning (mirroring upstream's
fallback).

## Usage

``` r
review_select(concepts, max_concepts, chat, max_active = 10, rpm = 500)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- max_concepts:

  Maximum number of concepts to activate.

- chat:

  An ellmer chat object.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

The concept tibble with `active` updated.

## Examples

``` r
if (FALSE) { # \dontrun{
concepts <- review_select(concepts, max_concepts = 5, chat)
concepts[concepts$active, c("name", "prompt")]
} # }
```
