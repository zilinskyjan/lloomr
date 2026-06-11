# Suggest concept-generation parameters

Heuristic parameter suggestion (mirrors upstream
`auto_suggest_parameters()`): quotes per document scale with the median
sentence count; bullets scale with quotes; concepts per cluster aim for
`target_n_concepts` overall across an assumed ~3 clusters.

## Usage

``` r
lloom_suggest_params(sess, target_n_concepts = 20)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- target_n_concepts:

  Desired total number of generated concepts. Default 20 (upstream).

## Value

A list: `filter_n_quotes`, `summ_n_bullets`, `synth_n_concepts`.

## Examples

``` r
if (FALSE) { # \dontrun{
params <- lloom_suggest_params(sess)
sess <- lloom_gen(sess, params = params)
} # }
```
