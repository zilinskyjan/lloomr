# Find documents needing another concept-induction iteration

Implements the LLooM loop operator: identifies documents that are either
not covered by any concept or covered only by generic concepts (those
matching at least half of all documents), and returns them for another
round of concept generation.

## Usage

``` r
loop_docs(
  score_df,
  text_col = "text",
  id_col,
  threshold = 1,
  generic_threshold = 0.5
)
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md).

- text_col, id_col:

  Column names for document text and IDs (`text_col` should name the
  text column in `score_df`, i.e. `"text"`).

- threshold:

  Minimum score counting as a match. Default 1.

- generic_threshold:

  Fraction of documents a concept must match to count as generic for
  coverage purposes. Default 0.5 (upstream).

## Value

A tibble of documents (`id_col`, `text_col`) to feed into the next
iteration, or `NULL` if iteration should stop (every document would be
included again, or none would).

## Examples

``` r
# Doc 1 matches the concept; docs 2-3 are uncovered -> returned for
# another round
score_df <- data.frame(
  doc_id = c("1", "2", "3"),
  text = c("covered doc", "uncovered doc", "another uncovered"),
  concept_id = "c1", concept_name = "Concept",
  score = c(1, 0, 0)
)
loop_docs(score_df, "text", "doc_id")
#> # A tibble: 2 × 2
#>   doc_id text             
#>   <chr>  <chr>            
#> 1 2      uncovered doc    
#> 2 3      another uncovered
```
