# Create a tibble of concepts

Constructor for the concept table used throughout lloomr. Vectorized
over `name` and `prompt`; a fresh unique `id` is generated for each
concept.

## Usage

``` r
new_concepts(
  name,
  prompt,
  example_ids = NULL,
  active = FALSE,
  summary = NA_character_,
  seed = NA_character_
)
```

## Arguments

- name:

  Character vector of concept names.

- prompt:

  Character vector of concept inclusion-criteria prompts (recycled
  rules: must match `length(name)`).

- example_ids:

  List of character vectors of representative document IDs, one element
  per concept (or a single character vector if creating one concept).
  Defaults to no examples.

- active:

  Logical; whether concepts start active. Default `FALSE` (matching
  upstream, where concepts are activated by selection).

- summary, seed:

  Optional character vectors (default `NA`).

## Value

A tibble with class `lloom_concepts`.

## Examples

``` r
new_concepts(
  name = c("Economic Anxiety", "Distrust of Media"),
  prompt = c(
    "Does the text express concern about economic conditions?",
    "Does the text express distrust toward news media?"
  )
)
#> <lloom_concepts>: 2 concepts (0 active)
#> # A tibble: 2 × 7
#>   id                               name  prompt example_ids active summary seed 
#>   <chr>                            <chr> <chr>  <list>      <lgl>  <chr>   <chr>
#> 1 6ad1a204-495d-968e-4488-d4419d8… Econ… Does … <chr [0]>   FALSE  NA      NA   
#> 2 5995e3b3-9b86-587b-8675-962957f… Dist… Does … <chr [0]>   FALSE  NA      NA   
```
