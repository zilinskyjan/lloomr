# Score documents against the session's active concepts

Runs
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
for the session (upstream `score()`): active concepts only, against the
full dataset (or `df`).

## Usage

``` r
lloom_score(
  sess,
  batch_size = 1,
  get_highlights = TRUE,
  score_all = FALSE,
  df = NULL,
  verbose = TRUE
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md).

- batch_size:

  Documents per LLM call. Default 1 (upstream session default; raise for
  cheaper, slightly less reliable scoring).

- get_highlights:

  Request supporting quotes. Default `TRUE` (upstream session default).

- score_all:

  Activate and score *all* concepts. Default `FALSE`.

- df:

  Optional alternative document set to score.

- verbose:

  Announce steps. Default `TRUE`.

## Value

The updated session (field `score_df`).

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_score(sess)                  # active concepts, full data
sess <- lloom_score(sess, score_all = TRUE)  # every generated concept

# Save the resulting scores:
readr::write_csv(lloom_results(sess), "scores.csv")
} # }
```
