# Heatmap of concept matches by group

The lloomr replacement for upstream's interactive matrix widget: a
ggplot2 heatmap of concepts (rows) by document groups (columns), where
fill encodes how common each concept is in each group and each tile is
labeled with the match count. Returns a ggplot object for further
customization.

## Usage

``` r
lloom_vis(
  sess,
  slice_col = NULL,
  norm_by = NULL,
  threshold = 1,
  max_slice_bins = 5,
  include_outlier = TRUE
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md).

- slice_col:

  Optional column of the session's data frame to slice by (e.g. a party
  or time variable).

- norm_by:

  `"slice"` (default when slicing: fraction of each group's documents),
  `"concept"`, or `"none"` (raw counts).

- threshold:

  Minimum score counting as a match. Default 1.

- max_slice_bins:

  Maximum bins for numeric slice columns. Default 5.

- include_outlier:

  Include the "Outlier" row. Default `TRUE`.

## Value

A ggplot object.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_score(lloom_gen(lloom_session(df, "text", "doc_id")))
lloom_vis(sess, slice_col = "party")
# It is a regular ggplot object:
lloom_vis(sess) + ggplot2::labs(title = "My title")
} # }
```
