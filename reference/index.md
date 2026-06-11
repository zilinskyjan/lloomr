# Package index

## The session pipeline

The high-level API: bundle your data and models in a session, then
generate, select, and score concepts in a few calls.

- [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md)
  : Create a LLooM session
- [`lloom_gen()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen.md)
  : Generate concepts: distill, cluster, synthesize, review
- [`lloom_score()`](https://zilinskyjan.github.io/lloomr/reference/lloom_score.md)
  : Score documents against the session's active concepts
- [`lloom_gen_auto()`](https://zilinskyjan.github.io/lloomr/reference/lloom_gen_auto.md)
  : Generate, select, and score in one call
- [`lloom_select()`](https://zilinskyjan.github.io/lloomr/reference/lloom_select.md)
  : Activate the best concepts in a session
- [`lloom_add_concept()`](https://zilinskyjan.github.io/lloomr/reference/lloom_add_concept.md)
  : Add a manual concept to a session
- [`lloom_results()`](https://zilinskyjan.github.io/lloomr/reference/lloom_results.md)
  : Get the score results from a session
- [`lloom_suggest_params()`](https://zilinskyjan.github.io/lloomr/reference/lloom_suggest_params.md)
  : Suggest concept-generation parameters
- [`lloom_estimate_gen_cost()`](https://zilinskyjan.github.io/lloomr/reference/lloom_estimate_gen_cost.md)
  : Estimate the cost of concept generation
- [`lloom_estimate_score_cost()`](https://zilinskyjan.github.io/lloomr/reference/lloom_estimate_score_cost.md)
  : Estimate the cost of scoring
- [`summary(`*`<lloom_session>`*`)`](https://zilinskyjan.github.io/lloomr/reference/summary.lloom_session.md)
  : Summarize a session's steps, timing, and cost

## Concepts

Concepts are tibbles — one row per concept, with a name and a yes/no
inclusion-criterion question. Write them by hand to score a human
codebook, or let the pipeline generate them.

- [`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md)
  : Create a tibble of concepts
- [`validate_concepts()`](https://zilinskyjan.github.io/lloomr/reference/validate_concepts.md)
  : Validate a concept tibble

## Pipeline operators

Every stage as a standalone function on plain data frames — distill,
cluster, synthesize, review, score, refine.

- [`distill_filter()`](https://zilinskyjan.github.io/lloomr/reference/distill_filter.md)
  : Distill documents to salient quotes

- [`distill_summarize()`](https://zilinskyjan.github.io/lloomr/reference/distill_summarize.md)
  : Distill documents to bullet-point summaries

- [`cluster_texts()`](https://zilinskyjan.github.io/lloomr/reference/cluster_texts.md)
  : Cluster texts by semantic similarity

- [`synthesize_concepts()`](https://zilinskyjan.github.io/lloomr/reference/synthesize_concepts.md)
  : Synthesize concepts from clustered examples

- [`review_concepts()`](https://zilinskyjan.github.io/lloomr/reference/review_concepts.md)
  : Review a concept set: remove, merge, and optionally select

- [`review_remove()`](https://zilinskyjan.github.io/lloomr/reference/review_remove.md)
  : Remove low-quality concepts

- [`review_merge()`](https://zilinskyjan.github.io/lloomr/reference/review_merge.md)
  : Merge overlapping concepts

- [`review_select()`](https://zilinskyjan.github.io/lloomr/reference/review_select.md)
  :

  Select the best concepts (sets `active`)

- [`score_concepts()`](https://zilinskyjan.github.io/lloomr/reference/score_concepts.md)
  : Score documents against concepts

- [`summarize_concept()`](https://zilinskyjan.github.io/lloomr/reference/summarize_concept.md)
  : Summarize a concept from its matching examples

- [`refine_concepts()`](https://zilinskyjan.github.io/lloomr/reference/refine_concepts.md)
  : Refine concepts by match prevalence

- [`loop_docs()`](https://zilinskyjan.github.io/lloomr/reference/loop_docs.md)
  : Find documents needing another concept-induction iteration

## One topic per document

Multi-label scores are the default; these helpers produce a mutually
exclusive partition from a fixed topic set.

- [`assign_topics()`](https://zilinskyjan.github.io/lloomr/reference/assign_topics.md)
  : Assign each document to exactly one topic
- [`slot_by_score()`](https://zilinskyjan.github.io/lloomr/reference/slot_by_score.md)
  : Slot each document into one topic from existing scores

## Results: saving, reshaping, visualizing

- [`scores_wide()`](https://zilinskyjan.github.io/lloomr/reference/scores_wide.md)
  : Reshape scores to one row per document (wide matrix)
- [`lloom_write()`](https://zilinskyjan.github.io/lloomr/reference/lloom_write.md)
  : Write all session results to a folder
- [`lloom_vis()`](https://zilinskyjan.github.io/lloomr/reference/lloom_vis.md)
  : Heatmap of concept matches by group
- [`concept_matrix()`](https://zilinskyjan.github.io/lloomr/reference/concept_matrix.md)
  : Build the concept x slice match matrix
- [`lloom_export()`](https://zilinskyjan.github.io/lloomr/reference/lloom_export.md)
  : Export a per-concept results table
- [`concept_similarity()`](https://zilinskyjan.github.io/lloomr/reference/concept_similarity.md)
  : Pairwise similarity between concepts
- [`lloom_concept_map()`](https://zilinskyjan.github.io/lloomr/reference/lloom_concept_map.md)
  : Map concepts into 2D by their similarity

## LLM layer and prompts

The infrastructure underneath: concurrent structured-output queries,
embeddings, prompt templates, and response schemas.

- [`ll_query()`](https://zilinskyjan.github.io/lloomr/reference/ll_query.md)
  : Run many structured LLM queries concurrently
- [`ll_embed()`](https://zilinskyjan.github.io/lloomr/reference/ll_embed.md)
  : Embed texts with the OpenAI embeddings API
- [`lloom_prompt()`](https://zilinskyjan.github.io/lloomr/reference/lloom_prompt.md)
  : Get the default prompt template for a LLooM step
- [`render_prompt()`](https://zilinskyjan.github.io/lloomr/reference/render_prompt.md)
  : Render a prompt template with arguments
- [`validate_prompt()`](https://zilinskyjan.github.io/lloomr/reference/validate_prompt.md)
  : Validate a custom prompt template for a LLooM step
- [`lloom_type()`](https://zilinskyjan.github.io/lloomr/reference/lloom_type.md)
  : Get the structured-output schema for a LLooM step

## Utilities

- [`letter_to_score()`](https://zilinskyjan.github.io/lloomr/reference/letter_to_score.md)
  : Convert A-E Likert letters to numeric scores
- [`examples_to_json()`](https://zilinskyjan.github.io/lloomr/reference/examples_to_json.md)
  : Format documents as the JSON examples block used in scoring prompts
- [`filter_empty_rows()`](https://zilinskyjan.github.io/lloomr/reference/filter_empty_rows.md)
  : Drop rows whose text column is missing or empty
- [`robust_json_parse()`](https://zilinskyjan.github.io/lloomr/reference/robust_json_parse.md)
  : Robustly parse a JSON object out of an LLM text response
