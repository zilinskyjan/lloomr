# Render a prompt template with arguments

Interpolates a `glue`-style template with values from a named list.
Values inserted into the template are *not* re-interpolated, so JSON or
braces inside argument values are safe.

## Usage

``` r
render_prompt(template, args)
```

## Arguments

- template:

  Template string with `{placeholder}` fields.

- args:

  Named list of values to interpolate.

## Value

A length-1 character string.

## Examples

``` r
render_prompt("Summarize {ex} in {n} words.", list(ex = "some text", n = 5))
#> [1] "Summarize some text in 5 words."
```
