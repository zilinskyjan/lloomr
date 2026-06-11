# Create a LLooM session

Bundles the data, the models for each pipeline step, and (as the
pipeline runs) all intermediate and final results. Step functions
([`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md),
[`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md))
take and return the session, so the idiom is
`sess <- lloom_gen(sess, ...)`.

## Usage

``` r
lloom_session(
  df,
  text_col,
  id_col = NULL,
  distill_chat = NULL,
  synth_chat = NULL,
  score_chat = NULL,
  embed_fn = NULL,
  embed_model = "text-embedding-3-large"
)
```

## Arguments

- df:

  Data frame with one row per document.

- text_col:

  Name of the text column.

- id_col:

  Name of the document ID column; if `NULL`, an `id` column of row
  numbers is created (with a message). IDs must be unique.

- distill_chat, synth_chat, score_chat:

  ellmer chat objects for the distill, synthesize/review, and score
  steps. Defaults: gpt-5.4-nano for the cheap high-volume steps
  (distill, score) and gpt-5.2 for concept synthesis (requires
  `OPENAI_API_KEY` if any default is used). Upstream's defaults were
  gpt-4o-mini / gpt-4o; lloomr tracks newer models (deviation D10 in the
  comparison document).

- embed_fn:

  Embedding function for clustering (see
  [`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md)).
  Default:
  [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  with `embed_model`.

- embed_model:

  Embedding model for the default `embed_fn`.

## Value

An object of class `lloom_session`.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_session(df, text_col = "text", id_col = "doc_id")

# Or with explicit models per step:
sess <- lloom_session(
  df, "text", "doc_id",
  distill_chat = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none"),
  synth_chat   = ellmer::chat_openai(model = "gpt-5.2", echo = "none"),
  score_chat   = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
)
} # }
```
