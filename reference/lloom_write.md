# Write all session results to a folder

One call to persist a finished analysis (after
[`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md)).
Writes to `dir`:

## Usage

``` r
lloom_write(sess, dir, prefix = NULL)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md).

- dir:

  Output directory (created if needed).

- prefix:

  Optional filename prefix (e.g. `"study1"` gives
  `study1_scores_long.csv`).

## Value

Invisibly, a named character vector of the written file paths.

## Details

- `scores_long.csv` — the full score table
  ([`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md)):
  one row per (document, concept) pair with scores, rationales,
  highlights.

- `scores_wide.csv` — one row per document, one column per concept
  ([`scores_wide()`](https://zilinskyjan.github.io/lloomr/reference/scores_wide.md)),
  ready to join onto your main dataset.

- `concepts.csv` — the concept table (names, prompts, active flags).

- `concept_summary.csv` — the per-concept evidence table
  ([`lloom_export()`](https://zilinskyjan.github.io/lloomr/reference/lloom_export.md)
  with quotes collapsed into single cells).

- `session.rds` — the entire session object; restore with
  [`readRDS()`](https://rdrr.io/r/base/readRDS.html) (chat objects
  survive and keep working).

For just the scores, you never need this function — the score table is a
plain data frame: `readr::write_csv(lloom_results(sess), "scores.csv")`.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_score(lloom_gen(lloom_session(df, "text", "doc_id")))
lloom_write(sess, "results/")

# Later, in a fresh R session:
sess <- readRDS("results/session.rds")
} # }
```
