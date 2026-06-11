# Validate a custom prompt template for a LLooM step

Checks that a custom template contains all placeholder fields the step's
operator will interpolate (mirrors `validate_prompt()` in upstream
`workbench.py`). Throws an error listing any missing fields.

## Usage

``` r
validate_prompt(step, prompt)
```

## Arguments

- step:

  Step name (see
  [`lloom_prompt()`](https://zilinskyjan.github.io/lloomr/reference/lloom_prompt.md)).

- prompt:

  Custom template string.

## Value

Invisibly, `prompt` (so it can be piped onward).

## Examples

``` r
# The default template always validates
validate_prompt("distill_summarize", lloom_prompt("distill_summarize"))

# A custom template missing required fields errors
try(validate_prompt("distill_summarize", "Summarize {ex} please."))
#> Error in validate_prompt("distill_summarize", "Summarize {ex} please.") : 
#>   Custom prompt for "distill_summarize" is missing required template
#> field: "n_bullets", "seeding_phrase", and "n_words".
#> ℹ All required fields: "ex", "n_bullets", "seeding_phrase", and "n_words".
#> ℹ See `lloom_prompt("distill_summarize")` for the default template.
```
