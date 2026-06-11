# Activate the best concepts in a session

Convenience wrapper around
[`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md)
(upstream `select_auto()`).

## Usage

``` r
lloom_select(sess, max_concepts)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  after
  [`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md).

- max_concepts:

  Maximum number of concepts to activate.

## Value

The updated session.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_select(sess, max_concepts = 5)
} # }
```
