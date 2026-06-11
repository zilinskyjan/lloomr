# Embed texts with the OpenAI embeddings API

Replaces upstream `get_embeddings()` / `call_embed_fn()`. Newlines are
replaced with spaces (as upstream, since they can degrade embedding
quality) and requests are batched. Any operator that takes an `embed_fn`
argument accepts a drop-in replacement with this signature, so other
embedding providers (or precomputed embeddings) can be used.

## Usage

``` r
ll_embed(
  texts,
  model = "text-embedding-3-large",
  api_key = Sys.getenv("OPENAI_API_KEY"),
  batch_size = 2048,
  dimensions = NULL,
  base_url = "https://api.openai.com/v1"
)
```

## Arguments

- texts:

  Character vector of texts to embed.

- model:

  OpenAI embedding model name. Default `"text-embedding-3-large"` (the
  upstream default for clustering).

- api_key:

  API key; defaults to the `OPENAI_API_KEY` environment variable.

- batch_size:

  Maximum texts per request. Default 2048 (upstream default; also the
  OpenAI API maximum).

- dimensions:

  Optional reduced dimensionality (supported by text-embedding-3
  models).

- base_url:

  API base URL (override for Azure/compatible endpoints).

## Value

A numeric matrix with `length(texts)` rows.

## Examples

``` r
if (FALSE) { # \dontrun{
emb <- ll_embed(c("politics and elections", "sports scores"),
                model = "text-embedding-3-small")
dim(emb)
} # }
```
