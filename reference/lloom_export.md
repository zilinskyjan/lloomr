# Export a per-concept results table

One row per active concept with its criteria, prevalence, and evidence
(replaces upstream `export_df()` / `__get_df_for_export()`).

## Usage

``` r
lloom_export(sess, threshold = 1, max_highlights = 3, collapse = FALSE)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md).

- threshold:

  Minimum score counting as a match. Default 1.

- max_highlights:

  Maximum highlight quotes kept per concept. Default 3 (as upstream).

- collapse:

  If `TRUE`, collapse the `rep_examples` and `highlights` list columns
  into single `" | "`-separated strings, so the table can be written
  straight to CSV. Default `FALSE`.

## Value

A tibble: `concept`, `criteria`, `summary`, `rep_examples` (list column:
the concept's exemplar documents), `prevalence`, `n_matches`,
`highlights` (list column).

## Examples

``` r
if (FALSE) { # \dontrun{
lloom_export(sess)  # after lloom_gen() and lloom_score()

# CSV-safe version (list columns collapsed to text):
readr::write_csv(lloom_export(sess, collapse = TRUE), "concept_summary.csv")
} # }
```
