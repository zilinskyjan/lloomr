# Pairwise similarity between concepts

Computes a symmetric concept-by-concept similarity matrix, either from
embeddings of the concept definitions (`method = "embedding"`: cosine
similarity of the embedded `"name: prompt"` texts) or from scoring
results (`method = "scores"`: Pearson correlation of the concepts' score
vectors across documents).

## Usage

``` r
concept_similarity(
  concepts,
  method = c("embedding", "scores"),
  score_df = NULL,
  id_col = NULL,
  embed_fn = NULL,
  embed_model = "text-embedding-3-large"
)
```

## Arguments

- concepts:

  A concept tibble (see
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)).

- method:

  `"embedding"` (semantic similarity of the concept definitions) or
  `"scores"` (empirical co-matching in a scored corpus).

- score_df:

  Required for `method = "scores"`: output of
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
  /
  [`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md).

- id_col:

  Required for `method = "scores"`: the document ID column in
  `score_df`.

- embed_fn:

  Embedding function for `method = "embedding"` (character vector in,
  matrix out). Defaults to
  [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  with `embed_model`.

- embed_model:

  Embedding model for the default `embed_fn`.

## Value

A symmetric numeric matrix with concept names as dimnames. Diagonal is
1.

## Examples

``` r
if (FALSE) { # \dontrun{
cc <- sess$concepts[sess$concepts$active, ]
concept_similarity(cc)                          # semantic
concept_similarity(cc, method = "scores",       # empirical
                   score_df = lloom_results(sess), id_col = "doc_id")
} # }
```
