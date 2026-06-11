# Get the default prompt template for a LLooM step

Returns the prompt template used by a given pipeline step. Templates use
`glue`-style placeholders (e.g. `{ex}`, `{n_quotes}`); customized
versions can be passed back to the corresponding operator via its
`prompt_template` argument after checking them with
[`validate_prompt()`](https://zilinskyjan.github.io/lloomr/reference/validate_prompt.md).

## Usage

``` r
lloom_prompt(step)
```

## Arguments

- step:

  One of "distill_filter", "distill_summarize", "synthesize",
  "review_remove", "review_remove_seed", "review_merge",
  "review_select", "score", "score_highlight", "assign_topic",
  "summarize_concept", "auto_eval".

## Value

A length-1 character template.

## Examples

``` r
cat(lloom_prompt("distill_summarize"))
#> 
#> I have the following TEXT EXAMPLE:
#> {ex}
#> 
#> Summarize the main point of this EXAMPLE {seeding_phrase} into {n_bullets} bullet points, where each bullet point is a {n_words} word phrase. Respond ONLY with a valid JSON in the following format:
#> {{
#>     "bullets": [ "<BULLET_1>", "<BULLET_2>", ... ]
#> }}
```
