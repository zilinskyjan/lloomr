# Changelog

## lloomr (development version)

### Bug fixes

- Printing a concept table after dplyr column subsetting (e.g.
  `sess$concepts |> select(name)`) no longer warns about an unknown
  `active` column or falsely reports “0 active”. The `<lloom_concepts>`
  header is now shown only when the full concept structure is present.

### New features

- Concept proximity analysis:
  [`concept_similarity()`](https://zilinskyjan.github.io/lloomr/reference/concept_similarity.md)
  computes pairwise concept similarity three ways — semantically
  (embeddings of the concept definitions), empirically (correlation of
  score vectors across documents), or corpus-grounded
  (`method = "centroids"`: cosine similarity between the centroids of
  each concept’s matched documents) — and
  [`lloom_concept_map()`](https://zilinskyjan.github.io/lloomr/reference/lloom_concept_map.md)
  plots concepts in 2D so closely related concepts appear near each
  other (point size = prevalence).
- [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  gains a `chat` argument: one ellmer chat object (any provider)
  configures all three pipeline steps; step-specific arguments still
  override it.
- [`review_remove()`](https://zilinskyjan.github.io/lloomr/reference/review_remove.md)
  refuses to remove *all* concepts at once (it keeps them and warns with
  guidance), so auto-review can no longer leave
  [`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md)
  with an empty concept set.
- New results-persistence helpers:
  [`scores_wide()`](https://zilinskyjan.github.io/lloomr/reference/scores_wide.md)
  (document x concept matrix with sanitized column names and join-safety
  assertions) and
  [`lloom_write()`](https://zilinskyjan.github.io/lloomr/reference/lloom_write.md)
  (one call writes long/wide scores, the concept table, the evidence
  table, and `session.rds`).
- `lloom_export(collapse = TRUE)` flattens list columns so the evidence
  table writes straight to CSV.
- Documentation: explicit saving guidance (`readr::write_csv(...)`) in
  the manual, vignette, and README; new vignette section on scoring a
  human-written codebook without running concept generation.

## lloomr 0.1.0

First release. Complete R implementation of the LLooM concept-induction
algorithm (Lam et al., 2024, CHI), translated from the Python package
`text_lloom` (upstream commit 8252533).

### Core pipeline (faithful translation)

- Distill operators:
  [`distill_filter()`](https://zilinskyjan.github.io/lloomr/reference/distill_filter.md),
  [`distill_summarize()`](https://zilinskyjan.github.io/lloomr/reference/distill_summarize.md).
- Clustering:
  [`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md)
  (embeddings + UMAP + HDBSCAN), with a reproducibility `seed` and a
  pluggable `embed_fn`.
- Concept synthesis and review:
  [`synthesize_concepts()`](https://zilinskyjan.github.io/lloomr/reference/synthesize_concepts.md),
  [`review_remove()`](https://zilinskyjan.github.io/lloomr/reference/review_remove.md),
  [`review_merge()`](https://zilinskyjan.github.io/lloomr/reference/review_merge.md),
  [`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md),
  [`review_concepts()`](https://zilinskyjan.github.io/lloomr/reference/review_concepts.md).
- Scoring and refinement:
  [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md),
  [`summarize_concept()`](https://zilinskyjan.github.io/lloomr/reference/summarize_concept.md),
  [`refine_concepts()`](https://zilinskyjan.github.io/lloomr/reference/refine_concepts.md),
  [`loop_docs()`](https://zilinskyjan.github.io/lloomr/reference/loop_docs.md).
- Session pipeline:
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md),
  [`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md),
  [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md),
  [`lloom_gen_auto()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen_auto.md),
  cost estimators,
  [`summary()`](https://rdrr.io/r/base/summary.html)/[`print()`](https://rdrr.io/r/base/print.html)
  methods.
- Visualization and export:
  [`concept_matrix()`](https://zilinskyjan.github.io/lloomr/reference/concept_matrix.md),
  [`lloom_vis()`](https://zilinskyjan.github.io/lloomr/reference/lloom_vis.md),
  [`lloom_export()`](https://zilinskyjan.github.io/lloomr/reference/lloom_export.md).

### Beyond the Python original

- Single-label classification into a fixed topic set:
  [`assign_topics()`](https://zilinskyjan.github.io/lloomr/reference/assign_topics.md)
  (forced-choice, schema-constrained) and
  [`slot_by_score()`](https://zilinskyjan.github.io/lloomr/reference/slot_by_score.md)
  (argmax over existing scores).
- Provider-agnostic LLM layer via ellmer with structured output (typed
  schemas instead of JSON-from-text parsing); works with OpenAI,
  Anthropic, Gemini, and local models.
- `lloom_gen(sample_n = )`: generate concepts from a sample while
  scoring the full dataset.
- Token/cost usage attached to every LLM-calling result.
- Four upstream bugs fixed (batched-synthesis misattribution,
  merge-guard no-op and ID overwrite, dedupe inconsistency, silent score
  backfill) — see the project’s comparison document for details.

Default session models: gpt-5.4-nano (distill, score) and gpt-5.2
(synthesis); any ellmer chat object can be substituted per step.
