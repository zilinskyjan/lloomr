# Run many structured LLM queries concurrently

The workhorse behind every LLooM operator (replaces upstream
`multi_query_gpt_wrapper()`). Sends all prompts concurrently through
[`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
with the given output schema and returns one parsed result per prompt.
Failed queries yield `NULL` (with a warning) rather than aborting the
batch, mirroring upstream behavior.

## Usage

``` r
ll_query(chat, prompts, type, max_active = 10, rpm = 500)
```

## Arguments

- chat:

  An ellmer chat object, e.g.
  [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html).

- prompts:

  Character vector or list of prompt strings.

- type:

  An ellmer type spec describing the response shape (see
  [`lloom_type()`](https://zilinskyjan.github.io/lloomr/reference/lloom_type.md)).

- max_active:

  Maximum number of simultaneous requests. Default 10.

- rpm:

  Requests-per-minute throttle. Default 500.

## Value

A list with one element per prompt: the parsed result (a list matching
`type`), or `NULL` if that query failed. Token/cost usage for the call
is attached as attribute `"usage"` (a data frame, or `NULL` when
unavailable).

## Examples

``` r
if (FALSE) { # \dontrun{
chat <- ellmer::chat_openai(model = "gpt-5.4-nano", echo = "none")
prompts <- sapply(c("The economy is improving.", "Media trust is falling."),
  function(ex) render_prompt(
    lloom_prompt("distill_summarize"),
    list(ex = ex, seeding_phrase = "", n_bullets = 2, n_words = "3-5")
  ))
res <- ll_query(chat, prompts, lloom_type("distill_summarize"))
str(res)
attr(res, "usage")  # tokens and dollars
} # }
```
