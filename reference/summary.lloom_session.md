# Summarize a session's steps, timing, and cost

Summarize a session's steps, timing, and cost

## Usage

``` r
# S3 method for class 'lloom_session'
summary(object, ...)
```

## Arguments

- object:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- ...:

  Unused.

## Value

A tibble: one row per executed step with seconds, tokens, and price
(price `NA` where the provider reports none).

## Examples

``` r
if (FALSE) { # \dontrun{
summary(sess)  # step | seconds | input_tokens | output_tokens | price
} # }
```
