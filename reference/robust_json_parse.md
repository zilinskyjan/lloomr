# Robustly parse a JSON object out of an LLM text response

Fallback parser for non-structured responses (mirrors `json_load()`
upstream): trims to the outermost `{...}` (dropping markdown fences or
chatter around the JSON), parses, and optionally extracts one top-level
key. Returns `NULL` if nothing parseable is found. With ellmer
structured output this is rarely needed, but it is kept for custom
prompts and providers without structured-output support.

## Usage

``` r
robust_json_parse(s, top_level_key = NULL)
```

## Arguments

- s:

  A character string (or `NULL`).

- top_level_key:

  Optional name of a top-level element to extract.

## Value

A list (unsimplified JSON), the extracted element, or `NULL`.

## Examples

``` r
messy <- 'Sure! ```json\n{"bullets": ["one", "two"]}\n``` Hope that helps.'
robust_json_parse(messy, top_level_key = "bullets")
#> [[1]]
#> [1] "one"
#> 
#> [[2]]
#> [1] "two"
#> 
robust_json_parse("no json here")  # NULL
#> NULL
```
