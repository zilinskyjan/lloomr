# Concept data structures.
#
# Upstream represents concepts as a dict of Concept objects (concept.py).
# In R, concepts are a tibble with one row per concept, which makes joins
# with score results natural. Columns mirror Concept's fields:
#   id          chr  unique concept ID
#   name        chr  2-4 word concept name
#   prompt      chr  1-sentence inclusion-criteria prompt
#   example_ids list of chr, representative document IDs
#   active      lgl  whether the concept is selected for scoring
#   summary     chr  LLM-generated summary (NA until summarize_concept)
#   seed        chr  seed term used during generation (NA if unseeded)

#' Create a tibble of concepts
#'
#' Constructor for the concept table used throughout lloomr. Vectorized over
#' `name` and `prompt`; a fresh unique `id` is generated for each concept.
#'
#' @param name Character vector of concept names.
#' @param prompt Character vector of concept inclusion-criteria prompts
#'   (recycled rules: must match `length(name)`).
#' @param example_ids List of character vectors of representative document
#'   IDs, one element per concept (or a single character vector if creating
#'   one concept). Defaults to no examples.
#' @param active Logical; whether concepts start active. Default `FALSE`
#'   (matching upstream, where concepts are activated by selection).
#' @param summary,seed Optional character vectors (default `NA`).
#' @return A tibble with class `lloom_concepts`.
#' @export
#' @examples
#' new_concepts(
#'   name = c("Economic Anxiety", "Distrust of Media"),
#'   prompt = c(
#'     "Does the text express concern about economic conditions?",
#'     "Does the text express distrust toward news media?"
#'   )
#' )
new_concepts <- function(name,
                         prompt,
                         example_ids = NULL,
                         active = FALSE,
                         summary = NA_character_,
                         seed = NA_character_) {
  n <- length(name)
  stopifnot(is.character(name), is.character(prompt), length(prompt) == n)

  if (is.null(example_ids)) {
    example_ids <- replicate(n, character(0), simplify = FALSE)
  } else if (is.character(example_ids) && n == 1) {
    example_ids <- list(example_ids)
  }
  stopifnot(is.list(example_ids), length(example_ids) == n)
  example_ids <- lapply(example_ids, function(x) unique(as.character(x)))

  out <- tibble::tibble(
    id = new_id(n),
    name = name,
    prompt = prompt,
    example_ids = example_ids,
    active = rep_len(as.logical(active), n),
    summary = rep_len(as.character(summary), n),
    seed = rep_len(as.character(seed), n)
  )
  class(out) <- c("lloom_concepts", class(out))
  out
}

#' Validate a concept tibble
#'
#' Checks that a data frame has the structure produced by [new_concepts()].
#' Called internally by operators that consume concepts.
#'
#' @param concepts A data frame to check.
#' @return Invisibly, `concepts`.
#' @export
#' @examples
#' cc <- new_concepts("Economic Anxiety", "Does the text express economic concern?")
#' validate_concepts(cc)
#' try(validate_concepts(data.frame(name = "missing other columns")))
validate_concepts <- function(concepts) {
  required <- c("id", "name", "prompt", "example_ids", "active", "summary", "seed")
  missing_cols <- setdiff(required, names(concepts))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "Concept table is missing column{?s}: {.val {missing_cols}}. Use {.fn new_concepts}."
    )
  }
  if (anyDuplicated(concepts$id) > 0) {
    cli::cli_abort("Concept table has duplicated {.field id} values.")
  }
  if (!is.list(concepts$example_ids)) {
    cli::cli_abort("Column {.field example_ids} must be a list column.")
  }
  invisible(concepts)
}

#' Format concepts as the bullet list used in review prompts
#'
#' Produces the "- Name: ..., Prompt: ..." block that review_remove,
#' review_merge, and review_select interpolate into their prompts
#' (mirrors `concepts_list` construction upstream).
#'
#' @param concepts A concept tibble.
#' @return A length-1 string.
#' @noRd
concepts_to_text <- function(concepts) {
  validate_concepts(concepts)
  paste0("- Name: ", concepts$name, ", Prompt: ", concepts$prompt, collapse = "\n")
}

#' @export
print.lloom_concepts <- function(x, ...) {
  n_active <- sum(x$active, na.rm = TRUE)
  cli::cli_text("{.cls lloom_concepts}: {nrow(x)} concept{?s} ({n_active} active)")
  NextMethod()
}
