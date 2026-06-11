# Synthesize concepts from clustered examples

For each cluster of texts (from
[`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md)),
asks the LLM to propose high-level patterns: a 2-4 word name, a
1-sentence inclusion criterion ("prompt"), and the IDs of 1-2
best-exemplifying examples. This is the step that turns groups of
bullets into candidate concepts.

## Usage

``` r
synthesize_concepts(
  cluster_df,
  text_col,
  id_col,
  chat,
  cluster_id_col = "cluster_id",
  n_concepts = NULL,
  batch_size = NULL,
  pattern_phrase = "unifying pattern",
  dedupe = TRUE,
  seed = NULL,
  prompt_template = NULL,
  max_active = 10,
  rpm = 500
)
```

## Arguments

- cluster_df:

  Data frame with text, ID, and cluster columns (the output of
  [`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md)).

- text_col, id_col:

  Column names (strings) for text and document IDs.

- chat:

  An ellmer chat object (a capable model is recommended here; upstream
  defaults to gpt-4o for this step).

- cluster_id_col:

  Name of the cluster column. Default `"cluster_id"`.

- n_concepts:

  Number of concepts to request per cluster. Default `NULL` =
  `ceiling(cluster_size / 3)` (upstream heuristic).

- batch_size:

  Optional maximum examples per prompt; clusters larger than this are
  split across several prompts. Default `NULL` (no split).

- pattern_phrase:

  Noun used in the prompt for what to find. Default `"unifying pattern"`
  (upstream's session pipeline uses `"unique topic"`).

- dedupe:

  Drop concepts with identical name + prompt. Default `TRUE`.

- seed:

  Optional seed term steering synthesis; recorded in the concepts'
  `seed` field.

- prompt_template:

  Optional custom template (validated).

- max_active, rpm:

  Concurrency controls passed to
  [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md).

## Value

A list with:

- `concepts` — a
  [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)
  tibble (one row per concept, `active = FALSE`);

- `assignments` — a tibble linking concepts to their exemplar documents:
  `id_col`, `text_col`, `concept_id`, `concept_name`, `concept_prompt`,
  `seed` (only exemplar IDs actually present in the concept's cluster
  are kept, as upstream). Token/cost usage is attached to the list as
  attribute `"usage"`.

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-5.2", echo = "none")
clusters <- cluster_texts(bullets, "text", "post_id")
synth <- synthesize_concepts(clusters, "text", "post_id", chat)
synth$concepts
} # }
```
