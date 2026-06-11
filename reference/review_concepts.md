# Review a concept set: remove, merge, and optionally select

The full auto-review pass run after synthesis (upstream `review()`):
removes too-narrow/too-broad concepts (or, with `seed`, off-topic ones),
merges overlapping pairs, and — if `max_concepts` is given — activates
the best subset. If an `assignments` table from
[`synthesize_concepts()`](https://zilinskyjan.github.io/lloomr/reference/synthesize_concepts.md)
is supplied, it is kept in sync (removed concepts dropped, merged
concepts relabeled).

## Usage

``` r
review_concepts(
  concepts,
  chat,
  assignments = NULL,
  seed = NULL,
  max_concepts = NULL,
  max_active = 10,
  rpm = 500
)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- chat:

  An ellmer chat object.

- assignments:

  Optional assignments tibble from
  [`synthesize_concepts()`](https://zilinskyjan.github.io/lloomr/reference/synthesize_concepts.md)
  to keep in sync.

- seed:

  Optional seed term; switches to the seeded variant prompt.

- max_concepts:

  Optional; if supplied, runs
  [`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md)
  too.

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A list: `concepts`, `assignments` (or `NULL`), `removed` (character
names), `merged` (tibble).

## Examples

``` r
if (FALSE) { # \dontrun{
synth <- synthesize_concepts(clusters, "text", "post_id", chat)
reviewed <- review_concepts(synth$concepts, chat,
                            assignments = synth$assignments,
                            max_concepts = 8)
reviewed$concepts
} # }
```
