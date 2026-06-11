# lloomr

An R implementation of the **LLooM** concept-induction algorithm (Lam et
al., 2024, CHI 2024; Python package
[`text_lloom`](https://github.com/michelle123lam/lloom)).

From a collection of texts, lloomr induces interpretable **concepts** —
each a short name plus a one-sentence inclusion criterion — and scores
every document against every concept:

    distill (quotes → bullets) → cluster (embeddings + UMAP + HDBSCAN)
      → synthesize (LLM proposes concepts) → review (remove/merge/select)
      → score (every document × every concept) → refine / loop

LLM calls go through [ellmer](https://ellmer.tidyverse.org), so any
supported provider works (OpenAI, Anthropic, Gemini, local models), and
all responses are constrained by structured-output schemas rather than
parsed out of free text.

## Installation

``` r

# install.packages("pak")
pak::pak("zilinskyjan/lloomr")

# Alternative: 
# remotes::install_github("zilinskyjan/lloomr")
```

Set `OPENAI_API_KEY` in `~/.Renviron` for the default models — or pick
any provider yourself; the model choice is just an ellmer chat object:

``` r

sess <- lloom_session(df, "text", "doc_id",
  chat = ellmer::chat_anthropic(model = "claude-sonnet-4-6", echo = "none"))
```

## Quick start

``` r

library(lloomr)

sess <- lloom_session(df, text_col = "text", id_col = "doc_id")
lloom_estimate_gen_cost(sess)                  # pre-flight cost estimate
sess <- lloom_gen(sess, max_concepts = 8)      # induce + select concepts
sess <- lloom_score(sess)                      # score all documents
lloom_results(sess)                            # tidy (doc × concept) scores
lloom_vis(sess, slice_col = "party")           # heatmap by group
summary(sess)                                  # time, tokens, dollars

# Save your results — the score table is a plain data frame:
readr::write_csv(lloom_results(sess), "scores.csv")
lloom_write(sess, "results/")                  # or: everything in one call
```

Every pipeline step is also a standalone function on plain data frames
([`distill_summarize()`](https://zilinskyjan.github.io/lloomr/reference/distill_summarize.md),
[`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md),
[`synthesize_concepts()`](https://zilinskyjan.github.io/lloomr/reference/synthesize_concepts.md),
[`review_concepts()`](https://zilinskyjan.github.io/lloomr/reference/review_concepts.md),
[`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md),
…).

Beyond the Python original, lloomr adds **single-label classification**
into a fixed topic set:
[`assign_topics()`](https://zilinskyjan.github.io/lloomr/reference/assign_topics.md)
(forced-choice, schema- constrained) and
[`slot_by_score()`](https://zilinskyjan.github.io/lloomr/reference/slot_by_score.md)
(free argmax over existing scores).

**Concept generation is optional.** To score a human-written codebook,
skip generation entirely:

``` r

codebook <- new_concepts(
  name   = c("Economic Anxiety", "Media Distrust"),
  prompt = c("Does the text express concern about economic conditions?",
             "Does the text express distrust toward news media?"),
  active = TRUE
)
score_df <- score_concepts(df, "text", "doc_id", codebook, chat)
```

## Documentation

- [`vignette("lloomr")`](https://zilinskyjan.github.io/lloomr/articles/lloomr.md)
  — package vignette (pipeline, single-label classification,
  visualization)
- Function reference: every operator is documented with examples
  ([`?lloom_gen`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md),
  [`?score_concepts`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md),
  …)
- Default session models: gpt-5.4-nano for the cheap high-volume steps
  (distill, score), gpt-5.2 for concept synthesis; override any of them
  with `distill_chat` / `synth_chat` / `score_chat`

## License

BSD 3-Clause. Original algorithm and Python implementation by Michelle
Lam; AI-assisted R translation by Jan Zilinsky.
