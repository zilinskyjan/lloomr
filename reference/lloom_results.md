# Get the score results from a session

Returns the long score table: one row per (document, concept) pair with
the document ID, concept name, score, rationale, and highlight. It is a
plain tibble, so saving it is one line — see the examples. For one row
per document (to join onto your main dataset), reshape with
[`scores_wide()`](https://zilinskyjan.github.io/lloomr/reference/scores_wide.md);
to save everything a finished analysis produced in one call, use
[`lloom_write()`](https://zilinskyjan.github.io/lloomr/reference/lloom_write.md).

## Usage

``` r
lloom_results(sess)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md).

## Value

The long score tibble (see
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
score_df <- lloom_results(sess)

# Save the scores as a CSV (document IDs, concepts, scores, rationales):
readr::write_csv(score_df, "scores.csv")

# Or one row per document, one column per concept:
readr::write_csv(scores_wide(score_df, "doc_id"), "scores_wide.csv")
} # }
```
