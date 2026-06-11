# Get the structured-output schema for a LLooM step

Returns the `ellmer` type specification describing the response shape
for a pipeline step. Used internally with
[`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html);
exported so users supplying custom prompts can reuse or inspect the
expected output shape.

## Usage

``` r
lloom_type(step)
```

## Arguments

- step:

  One of `"distill_filter"`, `"distill_summarize"`, `"synthesize"`,
  `"review_remove"`, `"review_remove_seed"`, `"review_merge"`,
  `"review_select"`, `"score"`, `"score_highlight"`,
  `"summarize_concept"`, `"auto_eval"`.

## Value

An `ellmer` type object.

## Examples

``` r
lloom_type("synthesize")
#> <ellmer::TypeObject>
#>  @ description          : NULL
#>  @ required             : logi TRUE
#>  @ properties           :List of 1
#>  .. $ patterns: <ellmer::TypeArray>
#>  ..  ..@ description: NULL
#>  ..  ..@ required   : logi TRUE
#>  ..  ..@ items      : <ellmer::TypeObject>
#>  .. .. .. @ description          : NULL
#>  .. .. .. @ required             : logi TRUE
#>  .. .. .. @ properties           :List of 3
#>  .. .. .. .. $ name       : <ellmer::TypeBasic>
#>  .. .. .. ..  ..@ description: chr "2-4 word name for the pattern"
#>  .. .. .. ..  ..@ required   : logi TRUE
#>  .. .. .. ..  ..@ type       : chr "string"
#>  .. .. .. .. $ prompt     : <ellmer::TypeBasic>
#>  .. .. .. ..  ..@ description: chr "1-sentence yes/no question to determine whether the pattern applies to a new text example"
#>  .. .. .. ..  ..@ required   : logi TRUE
#>  .. .. .. ..  ..@ type       : chr "string"
#>  .. .. .. .. $ example_ids: <ellmer::TypeArray>
#>  .. .. .. ..  ..@ description: chr "IDs of 1-2 examples that best exemplify the pattern"
#>  .. .. .. ..  ..@ required   : logi TRUE
#>  .. .. .. ..  ..@ items      : <ellmer::TypeBasic>
#>  .. .. .. .. .. .. @ description: NULL
#>  .. .. .. .. .. .. @ required   : logi TRUE
#>  .. .. .. .. .. .. @ type       : chr "string"
#>  .. .. .. @ additional_properties: logi FALSE
#>  @ additional_properties: logi FALSE
```
