# Generate, select, and score in one call

Convenience pipeline (upstream `gen_auto()`):
[`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md)
with selection of `max_concepts`, then
[`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md).

## Usage

``` r
lloom_gen_auto(
  sess,
  max_concepts = 8,
  seed = NULL,
  params = NULL,
  n_synth = 1,
  sample_n = NULL,
  batch_size = 1,
  get_highlights = TRUE,
  verbose = TRUE
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- max_concepts:

  If supplied,
  [`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md)
  activates the best subset at the end.

- seed:

  Optional seed term steering all generation steps.

- params:

  Parameter list as from
  [`lloom_suggest_params()`](https://zilinskyjan.github.io/lloomr/reference/lloom_suggest_params.md);
  `NULL` = auto-suggest (with a message).

- n_synth:

  Number of synthesize iterations; iterations after the first re-cluster
  the previous round's concepts (upstream behavior). Default 1.

- sample_n:

  Optional: generate concepts from a random sample of this many
  documents (scoring still uses the full data). lloomr extension.

- batch_size:

  Documents per LLM call. Default 1 (upstream session default; raise for
  cheaper, slightly less reliable scoring).

- get_highlights:

  Request supporting quotes. Default `TRUE` (upstream session default).

- verbose:

  Announce steps. Default `TRUE`.

## Value

The updated session.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_session(df, "text", "doc_id")
sess <- lloom_gen_auto(sess, max_concepts = 8)
lloom_results(sess)
} # }
```
