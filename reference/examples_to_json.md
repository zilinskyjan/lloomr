# Format documents as the JSON examples block used in scoring prompts

Produces
`{"cur_examples": [{"example_id": ..., "example_text": ...}, ...]}`,
mirroring `get_examples_dict()` + `dict_to_json()` upstream. No brace
escaping is needed because
[`render_prompt()`](https://zilinskyjan.github.io/lloomr/reference/render_prompt.md)
does not re-interpolate inserted values.

## Usage

``` r
examples_to_json(df, id_col, text_col)
```

## Arguments

- df:

  Data frame of documents.

- id_col, text_col:

  Column names (strings) for document IDs and text.

## Value

A length-1 JSON string.

## Examples

``` r
df <- data.frame(doc_id = 1:2, text = c("First post.", "Second post."))
examples_to_json(df, "doc_id", "text")
#> [1] "{\"cur_examples\":[{\"example_id\":\"1\",\"example_text\":\"First post.\"},{\"example_id\":\"2\",\"example_text\":\"Second post.\"}]}"
```
