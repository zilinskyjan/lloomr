# Add a manual concept to a session

Adds a user-defined concept (active by default), e.g. a theory-driven
category the model did not propose (upstream `add()`, without the
automatic scoring).

## Usage

``` r
lloom_add_concept(sess, name, prompt, active = TRUE)
```

## Arguments

- sess:

  A
  [`lloom_session()`](https://zilinskyjan.github.io/lloomr/reference/lloom_session.md).

- name, prompt:

  Concept name and inclusion-criterion question.

- active:

  Whether the concept starts active. Default `TRUE`.

## Value

The updated session.

## Examples

``` r
if (FALSE) { # \dontrun{
sess <- lloom_add_concept(
  sess,
  name = "Conspiratorial Framing",
  prompt = "Does the text frame events as a hidden coordinated plot?"
)
} # }
```
