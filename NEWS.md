# lloomr (development version)

## Bug fixes

* Printing a concept table after dplyr column subsetting (e.g.
  `sess$concepts |> select(name)`) no longer warns about an unknown
  `active` column or falsely reports "0 active". The
  `<lloom_concepts>` header is now shown only when the full concept
  structure is present.

## New features

* `lloom_session()` gains a `chat` argument: one ellmer chat object (any
  provider) configures all three pipeline steps; step-specific arguments
  still override it.
* `review_remove()` refuses to remove *all* concepts at once (it keeps
  them and warns with guidance), so auto-review can no longer leave
  `lloom_gen()` with an empty concept set.
* New results-persistence helpers: `scores_wide()` (document x concept
  matrix with sanitized column names and join-safety assertions) and
  `lloom_write()` (one call writes long/wide scores, the concept table,
  the evidence table, and `session.rds`).
* `lloom_export(collapse = TRUE)` flattens list columns so the evidence
  table writes straight to CSV.
* Documentation: explicit saving guidance (`readr::write_csv(...)`) in
  the manual, vignette, and README; new vignette section on scoring a
  human-written codebook without running concept generation.

# lloomr 0.1.0

First release. Complete R implementation of the LLooM concept-induction
algorithm (Lam et al., 2024, CHI), translated from the Python package
`text_lloom` (upstream commit 8252533).

## Core pipeline (faithful translation)

* Distill operators: `distill_filter()`, `distill_summarize()`.
* Clustering: `cluster_texts()` (embeddings + UMAP + HDBSCAN), with a
  reproducibility `seed` and a pluggable `embed_fn`.
* Concept synthesis and review: `synthesize_concepts()`,
  `review_remove()`, `review_merge()`, `review_select()`,
  `review_concepts()`.
* Scoring and refinement: `score_concepts()`, `summarize_concept()`,
  `refine_concepts()`, `loop_docs()`.
* Session pipeline: `lloom_session()`, `lloom_gen()`, `lloom_score()`,
  `lloom_gen_auto()`, cost estimators, `summary()`/`print()` methods.
* Visualization and export: `concept_matrix()`, `lloom_vis()`,
  `lloom_export()`.

## Beyond the Python original

* Single-label classification into a fixed topic set: `assign_topics()`
  (forced-choice, schema-constrained) and `slot_by_score()` (argmax over
  existing scores).
* Provider-agnostic LLM layer via ellmer with structured output (typed
  schemas instead of JSON-from-text parsing); works with OpenAI,
  Anthropic, Gemini, and local models.
* `lloom_gen(sample_n = )`: generate concepts from a sample while scoring
  the full dataset.
* Token/cost usage attached to every LLM-calling result.
* Four upstream bugs fixed (batched-synthesis misattribution, merge-guard
  no-op and ID overwrite, dedupe inconsistency, silent score backfill) —
  see the project's comparison document for details.

Default session models: gpt-5.4-nano (distill, score) and gpt-5.2
(synthesis); any ellmer chat object can be substituted per step.
