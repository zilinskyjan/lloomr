# Generate concepts: distill, cluster, synthesize, review

Runs the inductive half of the pipeline (upstream `gen()`): optionally
filter to quotes, summarize to bullets, cluster, synthesize concepts per
cluster, and auto-review (remove + merge; with `max_concepts`, also
select). The quote-filtering step is skipped when
`params$filter_n_quotes <= 1` (typical for short texts).

## Usage

``` r
lloom_gen(
  sess,
  seed = NULL,
  params = NULL,
  n_synth = 1,
  max_concepts = NULL,
  auto_review = TRUE,
  sample_n = NULL,
  verbose = TRUE
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- seed:

  Optional seed term steering all generation steps.

- params:

  Parameter list as from
  [`lloom_suggest_params()`](https://zilinskyjan.github.io/lloomr/reference/lloom_suggest_params.md);
  `NULL` = auto-suggest (with a message).

- n_synth:

  Number of synthesize iterations; iterations after the first re-cluster
  the previous round's concepts (upstream behavior). Default 1.

- max_concepts:

  If supplied,
  [`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md)
  activates the best subset at the end.

- auto_review:

  Run remove + merge review after synthesis. Default `TRUE`.

- sample_n:

  Optional: generate concepts from a random sample of this many
  documents (scoring still uses the full data). lloomr extension.

- verbose:

  Announce steps. Default `TRUE`.

## Value

The updated session (fields `df_filtered`, `df_bullets`, `clusters`,
`concepts`, `assignments`, `params`, `history`).

## Examples

``` r
if (FALSE) { # \dontrun{
# Generate concepts from a 200-doc sample, steered toward a topic,
# and activate the best 8
sess <- lloom_gen(sess, seed = "media trust", sample_n = 200,
                  max_concepts = 8)
sess$concepts
} # }
```
