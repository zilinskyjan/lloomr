# Map concepts into 2D by their similarity

Projects the concept similarity matrix into two dimensions (classical
multidimensional scaling of `1 - similarity`) and plots concepts as a
labeled scatter: nearby concepts are similar; when scores are available,
point size shows each concept's prevalence. The lloomr answer to "how
close are my concepts to each other?".

## Usage

``` r
lloom_concept_map(
  sess,
  method = c("embedding", "scores"),
  threshold = 1,
  embed_fn = NULL
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  with concepts (and, for `method = "scores"` or prevalence sizing,
  scores).

- method:

  `"embedding"` (semantic; default) or `"scores"` (empirical
  co-matching). See
  [`concept_similarity()`](https://zilinskyjan.github.io/lloomr/reference/concept_similarity.md).

- threshold:

  Minimum score counting as a match for prevalence sizing. Default 1.

- embed_fn:

  Optional embedding function override.

## Value

A ggplot object. The similarity matrix is attached as attribute
`"similarity"`, and the MDS coordinates as attribute `"coords"`.

## Examples

``` r
if (FALSE) { # \dontrun{
lloom_concept_map(sess)                      # semantic proximity
lloom_concept_map(sess, method = "scores")   # empirical proximity
} # }
```
