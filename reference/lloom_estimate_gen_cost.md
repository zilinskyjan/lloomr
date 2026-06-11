# Estimate the cost of concept generation

Pre-flight cost estimate for
[`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md)
(mirrors upstream `estimate_gen_cost()`, with token counts approximated
as characters/4 and prices looked up live from the provider's model list
where available). Estimates are rough; treat as order-of-magnitude.

## Usage

``` r
lloom_estimate_gen_cost(sess, params = NULL)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- params:

  Parameter list; `NULL` = auto-suggest.

## Value

A tibble with one row per step: estimated input/output tokens and
dollars (`NA` when the model's price is unknown).

## Examples

``` r
if (FALSE) { # \dontrun{
lloom_estimate_gen_cost(sess)  # before committing to lloom_gen()
} # }
```
