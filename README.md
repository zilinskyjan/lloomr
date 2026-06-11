# lloomr

An R implementation of the **LLooM** concept-induction algorithm
(Lam et al., 2024, CHI 2024; Python package
[`text_lloom`](https://github.com/michelle123lam/lloom)).

From a collection of texts, lloomr induces interpretable **concepts** —
each a short name plus a one-sentence inclusion criterion — and scores
every document against every concept:

```
distill (quotes → bullets) → cluster (embeddings + UMAP + HDBSCAN)
  → synthesize (LLM proposes concepts) → review (remove/merge/select)
  → score (every document × every concept) → refine / loop
```

LLM calls go through [ellmer](https://ellmer.tidyverse.org), so any
supported provider works (OpenAI, Anthropic, Gemini, local models), and
all responses are constrained by structured-output schemas rather than
parsed out of free text.

## Installation

```r
# install.packages("pak")
pak::pak("zilinskyjan/lloomr")

# Alternative: 
# remotes::install_github("zilinskyjan/lloomr")
```

Set `OPENAI_API_KEY` in `~/.Renviron` (or supply any ellmer chat objects).

## Quick start

```r
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
(`distill_summarize()`, `cluster_texts()`, `synthesize_concepts()`,
`review_concepts()`, `score_concepts()`, ...).

Beyond the Python original, lloomr adds **single-label classification**
into a fixed topic set: `assign_topics()` (forced-choice, schema-
constrained) and `slot_by_score()` (free argmax over existing scores).

## Documentation

- `vignette("lloomr")` — package vignette (pipeline, single-label
  classification, visualization)
- Function reference: every operator is documented with examples
  (`?lloom_gen`, `?score_concepts`, ...)
- Default session models: gpt-5.4-nano for the cheap high-volume steps
  (distill, score), gpt-5.2 for concept synthesis; override any of them
  with `distill_chat` / `synth_chat` / `score_chat`

## License

BSD 3-Clause. Original algorithm and Python implementation by Michelle
Lam; AI-assisted R translation by Jan Zilinsky.
