# Pairwise similarity between concepts

Computes a symmetric concept-by-concept similarity matrix using one of
three notions of proximity:

## Usage

``` r
concept_similarity(
  concepts,
  method = c("embedding", "scores", "centroids"),
  score_df = NULL,
  id_col = NULL,
  embed_fn = NULL,
  embed_model = "text-embedding-3-large",
  threshold = 1,
  doc_embeddings = NULL
)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- method:

  `"embedding"`, `"scores"`, or `"centroids"` (see above).

- score_df:

  Required for `"scores"` and `"centroids"`: output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
  /
  [`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md).

- id_col:

  Required for `"scores"` and `"centroids"`: the document ID column in
  `score_df`.

- embed_fn:

  Embedding function for `"embedding"` and `"centroids"` (character
  vector in, matrix out). Defaults to
  [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  with `embed_model`.

- embed_model:

  Embedding model for the default `embed_fn`.

- threshold:

  For `"centroids"`: minimum score for a document to count as a match.
  Default 1.

- doc_embeddings:

  For `"centroids"`: optional precomputed document embedding matrix with
  document IDs as rownames (avoids re-embedding, e.g. across repeated
  calls). Defaults to embedding the matched documents' text from
  `score_df`.

## Value

A symmetric numeric matrix with concept names as dimnames. Diagonal
is 1. Concepts that cannot be placed (absent from `score_df`, or no
matches for `"centroids"`) are dropped with a warning.

## Details

- `"embedding"` — *semantic*: cosine similarity of the embedded concept
  definitions (`"name: prompt"` texts). Do the concepts mean similar
  things?

- `"scores"` — *empirical co-matching*: Pearson correlation of the
  concepts' score vectors across documents. Do the concepts fire on the
  same documents?

- `"centroids"` — *corpus-grounded*: each concept is represented by the
  centroid (mean embedding) of the documents it matched; cosine
  similarity between centroids. Do the concepts' matches live in the
  same semantic territory? (Unlike `"scores"`, two concepts can be
  centroid-close while matching disjoint sets of documents.)

## Examples

``` r
if (FALSE) { # \dontrun{
cc <- sess$concepts[sess$concepts$active, ]
concept_similarity(cc)                          # semantic
concept_similarity(cc, method = "scores",       # empirical
                   score_df = lloom_results(sess), id_col = "doc_id")
concept_similarity(cc, method = "centroids",    # corpus-grounded
                   score_df = lloom_results(sess), id_col = "doc_id")
} # }
```
