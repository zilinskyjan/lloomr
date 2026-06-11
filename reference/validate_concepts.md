# Validate a concept tibble

Checks that a data frame has the structure produced by
[`new_concepts()`](https://zilinskyjan.github.io/lloomr/reference/new_concepts.md).
Called internally by operators that consume concepts.

## Usage

``` r
validate_concepts(concepts)
```

## Arguments

- concepts:

  A data frame to check.

## Value

Invisibly, `concepts`.

## Examples

``` r
cc <- new_concepts("Economic Anxiety", "Does the text express economic concern?")
validate_concepts(cc)
try(validate_concepts(data.frame(name = "missing other columns")))
#> Error in validate_concepts(data.frame(name = "missing other columns")) : 
#>   Concept table is missing columns: "id", "prompt", "example_ids",
#> "active", "summary", and "seed". Use `new_concepts()`.
```
