# Build the concept x slice match matrix

The tidy data behind
[`lloom_vis()`](https://zilinskyjan.github.io/lloomr/reference/lloom_vis.md)
(replaces upstream `prep_vis_dfs()`): for every group of documents (a
slice of a metadata column, plus "All") and every concept, the number of
matching documents. A synthetic "Outlier" concept counts documents
matching no concept (as upstream).

## Usage

``` r
concept_matrix(
  score_df,
  id_col,
  slice_df = NULL,
  slice_col = NULL,
  threshold = 1,
  norm_by = c("none", "slice", "concept"),
  max_slice_bins = 5,
  include_outlier = TRUE
)
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md).

- id_col:

  Column name for document IDs.

- slice_df:

  Optional data frame with `id_col` and `slice_col`, supplying a
  metadata column to slice by (typically the original input data).

- slice_col:

  Optional column in `slice_df` to group documents by. Character/factor
  columns use their values; numeric columns are binned into up to
  `max_slice_bins` quantile bins.

- threshold:

  Minimum score counting as a match. Default 1.

- norm_by:

  `"none"` (raw counts), `"slice"` (fraction of the slice's documents),
  or `"concept"` (fraction of the concept's total matches).

- max_slice_bins:

  Maximum bins for numeric slice columns. Default 5.

- include_outlier:

  Include the "Outlier" row. Default `TRUE`.

## Value

A tibble: `slice`, `concept`, `n` (match count), `value` (normalized per
`norm_by`), `slice_size` (documents in the slice).

## Examples

``` r
score_df <- data.frame(
  doc_id = rep(c("1", "2", "3", "4"), each = 2),
  concept_name = rep(c("Economy", "Media"), 4),
  score = c(1, 0,  1, 1,  0, 1,  0, 0)
)
meta <- data.frame(doc_id = as.character(1:4), party = c("D", "D", "R", "R"))
concept_matrix(score_df, "doc_id", slice_df = meta, slice_col = "party",
               norm_by = "slice")
#> # A tibble: 9 × 5
#>   slice concept     n slice_size value
#>   <chr> <chr>   <int>      <int> <dbl>
#> 1 All   Economy     2          4  0.5 
#> 2 All   Media       2          4  0.5 
#> 3 All   Outlier     1          4  0.25
#> 4 D     Economy     2          2  1   
#> 5 D     Media       1          2  0.5 
#> 6 D     Outlier     0          2  0   
#> 7 R     Economy     0          2  0   
#> 8 R     Media       1          2  0.5 
#> 9 R     Outlier     1          2  0.5 
```
