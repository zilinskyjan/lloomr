# Refine concepts by match prevalence

Data-driven pruning after scoring: drops concepts that matched too many
documents (generic) or too few (rare).

## Usage

``` r
refine_concepts(
  score_df,
  concepts,
  threshold = 1,
  generic_threshold = 0.75,
  rare_threshold = 0.05
)
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md).

- concepts:

  Concept tibble to refine.

- threshold:

  Minimum score counting as a match. Default 1 (upstream: only "strongly
  agree").

- generic_threshold:

  Concepts matching at least this fraction of documents are dropped as
  generic. Default 0.75 (upstream).

- rare_threshold:

  Concepts matching less than this fraction are dropped as rare. Default
  0.05 (upstream).

## Value

A list: `concepts` (kept rows), `generic` and `rare` (character vectors
of dropped concept names).

## Examples

``` r
concepts <- new_concepts(c("Everything", "Niche"), c("Is text?", "About X?"))
# "Everything" matches all 10 docs (generic); "Niche" matches none (rare)
score_df <- data.frame(
  doc_id = rep(1:10, 2),
  concept_id = rep(concepts$id, each = 10),
  concept_name = rep(concepts$name, each = 10),
  score = rep(c(1, 0), each = 10)
)
refine_concepts(score_df, concepts)
#> Dropping 1 generic concept: "Everything"
#> Dropping 1 rare concept: "Niche"
#> $concepts
#> <lloom_concepts>: 0 concepts (0 active)
#> # A tibble: 0 × 7
#> # ℹ 7 variables: id <chr>, name <chr>, prompt <chr>, example_ids <list>,
#> #   active <lgl>, summary <chr>, seed <chr>
#> 
#> $generic
#> [1] "Everything"
#> 
#> $rare
#> [1] "Niche"
#> 
```
