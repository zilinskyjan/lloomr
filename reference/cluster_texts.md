# Cluster texts by semantic similarity

Embeds each text (typically the bullets from
[`distill_summarize()`](https://zilinskyjan.github.io/lloomr/reference/distill_summarize.md)),
reduces the embeddings to 5 dimensions with UMAP, and clusters with
HDBSCAN. Each cluster later becomes one batch of examples for concept
synthesis.

## Usage

``` r
cluster_texts(
  df,
  text_col,
  id_col,
  embed_fn = NULL,
  embed_model = "text-embedding-3-large",
  embeddings = NULL,
  min_cluster_size = NULL,
  randomize = FALSE,
  batch_size = 20,
  seed = NULL
)
```

## Arguments

- df:

  Data frame of texts (typically one row per bullet).

- text_col, id_col:

  Column names (strings) for text and document IDs.

- embed_fn:

  Function mapping a character vector to an embedding matrix (one row
  per text). Defaults to
  [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  with `embed_model`. Supply your own to use a different provider.

- embed_model:

  Embedding model name passed to
  [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  when `embed_fn` is not supplied. Default `"text-embedding-3-large"`
  (upstream default).

- embeddings:

  Optional precomputed embedding matrix (one row per row of `df` *after*
  empty-text filtering); skips the embedding call.

- min_cluster_size:

  Minimum HDBSCAN cluster size. Default `NULL` = `max(3, floor(n/10))`
  (upstream heuristic).

- randomize:

  If `TRUE`, skip embeddings entirely and assign shuffled texts to
  pseudo-clusters of `batch_size` (upstream's `randomize` mode, an
  ablation/fallback).

- batch_size:

  Pseudo-cluster size for `randomize` mode. Default 20.

- seed:

  Optional integer; if supplied, clustering is reproducible (sets the
  RNG seed and runs UMAP single-threaded).

## Value

A tibble with columns `id_col`, `text_col`, and `cluster_id` (integer;
-1 = noise/outliers, clusters numbered from 0), sorted by `cluster_id`.
The embedding matrix is attached as attribute `"embeddings"` (`NULL` in
randomize mode).

## Examples

``` r
df <- data.frame(id = 1:6, text = paste("bullet point", 1:6))

# randomize mode needs no embeddings (upstream's ablation/fallback)
cluster_texts(df, "text", "id", randomize = TRUE, batch_size = 3, seed = 1)
#> # A tibble: 6 × 3
#>   id    text           cluster_id
#>   <chr> <chr>               <dbl>
#> 1 1     bullet point 1          0
#> 2 3     bullet point 3          0
#> 3 4     bullet point 4          0
#> 4 2     bullet point 2          1
#> 5 5     bullet point 5          1
#> 6 6     bullet point 6          1

if (FALSE) { # \dontrun{
# Real clustering: embeds via the OpenAI API, then UMAP + HDBSCAN
cluster_texts(bullets, "text", "post_id", seed = 42)
} # }
```
