# Convert A-E Likert letters to numeric scores

Maps the multiple-choice answers used in scoring prompts to numeric
scores (mirrors `parse_bucketed_score()` upstream): A = 1, B = 0.75, C =
0.5, D = 0.25, E = 0. Only the first character is used,
case-insensitively; anything unrecognized becomes 0 (the upstream
`NAN_SCORE` convention).

## Usage

``` r
letter_to_score(x)
```

## Arguments

- x:

  Character vector of answers (e.g. `c("A", "b", "E: disagree")`).

## Value

Numeric vector of the same length.

## Examples

``` r
letter_to_score(c("A", "b", "C.", "junk", NA))
#> [1] 1.00 0.75 0.50 0.00 0.00
```
