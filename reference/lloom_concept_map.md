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
  method = c("embedding", "scores", "centroids"),
  threshold = 1,
  embed_fn = NULL,
  doc_embeddings = NULL
)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  with concepts (and, for `method = "scores"` / `"centroids"` or
  prevalence sizing, scores).

- method:

  `"embedding"` (semantic; default), `"scores"` (empirical co-matching),
  or `"centroids"` (corpus-grounded: centroids of each concept's matched
  documents). See
  [`concept_similarity()`](https://zilinskyjan.github.io/lloomr/reference/concept_similarity.md).

- threshold:

  Minimum score counting as a match (for prevalence sizing and the
  `"centroids"` method). Default 1.

- embed_fn:

  Optional embedding function override.

- doc_embeddings:

  Optional precomputed document embeddings for `"centroids"` (see
  [`concept_similarity()`](https://zilinskyjan.github.io/lloomr/reference/concept_similarity.md)).

## Value

A ggplot object. The similarity matrix is attached as attribute
`"similarity"`, and the MDS coordinates as attribute `"coords"`.

## Details

Labels are placed with ggrepel when it is installed (recommended —
concepts that plot close together otherwise get overlapping labels).

## Examples

``` r
if (FALSE) { # \dontrun{
lloom_concept_map(sess)                        # semantic proximity
lloom_concept_map(sess, method = "scores")     # empirical proximity
lloom_concept_map(sess, method = "centroids")  # corpus-grounded
} # }
```
