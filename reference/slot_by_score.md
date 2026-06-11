# Slot each document into one topic from existing scores

Deterministic single-label assignment derived from a multi-label
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
result: each document gets the concept on which it scored highest. Costs
no LLM calls. Ties and non-matches are handled explicitly:

- if the document's best score is below `threshold`, it is labeled
  `other_label`;

- if several concepts tie for the best score, the first in `score_df`
  order wins and `tie = TRUE` flags the ambiguity.

## Usage

``` r
slot_by_score(score_df, id_col, threshold = 0.75, other_label = "Other")
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md).

- id_col:

  Column name for document IDs.

- threshold:

  Minimum best score required to assign a topic; below it the document
  is labeled `other_label`. Default 0.75 ("agree" or stronger).

- other_label:

  Label for documents matching no concept. Default `"Other"`.

## Value

A tibble with one row per document: `id_col`, `text`, `topic`,
`topic_score` (the winning score), `tie` (logical).

## Examples

``` r
score_df <- data.frame(
  doc_id = rep(c("1", "2", "3"), each = 2),
  text = rep(c("clear economy doc", "ambiguous doc", "off-topic doc"), each = 2),
  concept_name = rep(c("Economy", "Media"), 3),
  score = c(1, 0.25,   1, 1,   0.5, 0.25)
)
# Doc 1: Economy wins; doc 2: tie (flagged); doc 3: below threshold -> Other
slot_by_score(score_df, "doc_id")
#> # A tibble: 3 × 5
#>   doc_id text              topic   topic_score tie  
#>   <chr>  <chr>             <chr>         <dbl> <lgl>
#> 1 1      clear economy doc Economy         1   FALSE
#> 2 2      ambiguous doc     Economy         1   TRUE 
#> 3 3      off-topic doc     Other           0.5 FALSE
```
