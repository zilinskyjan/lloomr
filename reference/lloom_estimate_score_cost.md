# Estimate the cost of scoring

Pre-flight cost estimate for
[`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md)
(mirrors upstream `estimate_score_cost()`).

## Usage

``` r
lloom_estimate_score_cost(sess, n_concepts = NULL, batch_size = 1, df = NULL)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- n_concepts:

  Number of concepts to score; default = currently active concepts (or
  all, if none active).

- batch_size:

  Documents per call (affects prompt overhead).

- df:

  Optional alternative document set.

## Value

A one-row tibble: estimated input/output tokens and dollars.

## Examples

``` r
if (FALSE) { # \dontrun{
lloom_estimate_score_cost(sess, n_concepts = 8)
} # }
```
