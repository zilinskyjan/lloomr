# Reshape scores to one row per document (wide matrix)

Pivots the long score table from
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
/
[`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md)
into a document-by-concept matrix: one row per document, one column per
concept. This is the shape you want for joining scores onto your main
dataset for downstream analysis.

## Usage

``` r
scores_wide(
  score_df,
  id_col,
  value_col = "score",
  sanitize_names = TRUE,
  include_text = FALSE
)
```

## Arguments

- score_df:

  Output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
  /
  [`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md).

- id_col:

  Column name for document IDs.

- value_col:

  Which column to spread. Default `"score"`.

- sanitize_names:

  Convert concept names to valid, unique R column names. Default `TRUE`.

- include_text:

  Keep the document `text` column. Default `FALSE` (typically you join
  back to the original data by ID instead).

## Value

A tibble with one row per document. The concept-name-to-column mapping
is attached as attribute `"concept_names"` (a named character vector:
names are original concept names, values are column names).

## Details

Concept names are sanitized into valid, unique R column names by default
(e.g. `"China-related Disinformation"` becomes
`China.related.Disinformation`); the mapping is attached as attribute
`"concept_names"`. The output is guaranteed to have exactly one row per
document.

## Examples

``` r
score_df <- data.frame(
  doc_id = rep(c("1", "2"), each = 2),
  text = rep(c("first doc", "second doc"), each = 2),
  concept_name = rep(c("Media Distrust", "Vaccine Promotion"), 2),
  score = c(1, 0, 0.25, 1)
)
wide <- scores_wide(score_df, "doc_id")
wide
#> # A tibble: 2 × 3
#>   doc_id Media.Distrust Vaccine.Promotion
#>   <chr>           <dbl>             <dbl>
#> 1 1                1                    0
#> 2 2                0.25                 1
attr(wide, "concept_names")
#>      Media Distrust   Vaccine Promotion 
#>    "Media.Distrust" "Vaccine.Promotion" 

# Join back onto a main dataset, with the safety checks lloomr
# recommends for any merge:
main <- data.frame(doc_id = c("1", "2"), party = c("D", "R"))
stopifnot(nrow(wide) == nrow(main))
merged <- merge(main, wide, by = "doc_id")
stopifnot(nrow(merged) == nrow(main))
merged
#>   doc_id party Media.Distrust Vaccine.Promotion
#> 1      1     D           1.00                 0
#> 2      2     R           0.25                 1
```
