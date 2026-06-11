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
  chat = NULL,
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

- chat:

  Optional: a single ellmer chat object to use for **all** LLM steps.
  This is where the model and provider are chosen — any ellmer provider
  works
  ([`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html),
  [`ellmer::chat_anthropic()`](https://ellmer.tidyverse.org/reference/chat_anthropic.html),
  [`ellmer::chat_google_gemini()`](https://ellmer.tidyverse.org/reference/chat_google_gemini.html),
  [`ellmer::chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html),
  ...). Overridden by the step-specific arguments below.

- distill_chat, synth_chat, score_chat:

  ellmer chat objects for the distill, synthesize/review, and score
  steps individually (a common pattern: a cheap model for the
  high-volume distill/score steps, a capable one for synthesis).
  Defaults when neither these nor `chat` are given: gpt-5.4-nano for
  distill/score and gpt-5.2 for synthesis (requires `OPENAI_API_KEY`).
  Upstream's defaults were gpt-4o-mini / gpt-4o; lloomr tracks newer
  models (deviation D10 in the comparison document).

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

## Details

Note on embeddings: clustering uses OpenAI embeddings by default
regardless of the chat provider (Anthropic, for example, has no
embeddings API). To use another embedding provider — or precomputed
embeddings — supply `embed_fn`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Default models (OpenAI):
sess <- lloom_session(df, text_col = "text", id_col = "doc_id")

# One model of your choice for every step — this is where you pick
# the LLM (any ellmer provider):
sess <- lloom_session(df, "text", "doc_id",
  chat = ellmer::chat_anthropic(model = "claude-haiku-4-5", echo = "none")
)

# Or per step (cheap model for high-volume steps, capable for synthesis):
sess <- lloom_session(
  df, "text", "doc_id",
  distill_chat = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none"),
  synth_chat   = ellmer::chat_openai(model = "gpt-5.2", echo = "none"),
  score_chat   = ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
)
} # }
```
