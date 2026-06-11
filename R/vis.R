# Visualization and export.
# Replaces upstream visualize()/prep_vis_dfs() and the anywidget matrix
# widget (workbench.vis(), export_df()) with a tidy matrix data frame, a
# ggplot2 heatmap, and a per-concept export table.

#' Build the concept x slice match matrix
#'
#' The tidy data behind [lloom_vis()] (replaces upstream `prep_vis_dfs()`):
#' for every group of documents (a slice of a metadata column, plus "All")
#' and every concept, the number of matching documents. A synthetic
#' "Outlier" concept counts documents matching no concept (as upstream).
#'
#' @param score_df Output of [score_concepts()].
#' @param id_col Column name for document IDs.
#' @param slice_df Optional data frame with `id_col` and `slice_col`,
#'   supplying a metadata column to slice by (typically the original input
#'   data).
#' @param slice_col Optional column in `slice_df` to group documents by.
#'   Character/factor columns use their values; numeric columns are binned
#'   into up to `max_slice_bins` quantile bins.
#' @param threshold Minimum score counting as a match. Default 1.
#' @param norm_by `"none"` (raw counts), `"slice"` (fraction of the slice's
#'   documents), or `"concept"` (fraction of the concept's total matches).
#' @param max_slice_bins Maximum bins for numeric slice columns. Default 5.
#' @param include_outlier Include the "Outlier" row. Default `TRUE`.
#' @return A tibble: `slice`, `concept`, `n` (match count), `value`
#'   (normalized per `norm_by`), `slice_size` (documents in the slice).
#' @export
#' @examples
#' score_df <- data.frame(
#'   doc_id = rep(c("1", "2", "3", "4"), each = 2),
#'   concept_name = rep(c("Economy", "Media"), 4),
#'   score = c(1, 0,  1, 1,  0, 1,  0, 0)
#' )
#' meta <- data.frame(doc_id = as.character(1:4), party = c("D", "D", "R", "R"))
#' concept_matrix(score_df, "doc_id", slice_df = meta, slice_col = "party",
#'                norm_by = "slice")
concept_matrix <- function(score_df,
                           id_col,
                           slice_df = NULL,
                           slice_col = NULL,
                           threshold = 1,
                           norm_by = c("none", "slice", "concept"),
                           max_slice_bins = 5,
                           include_outlier = TRUE) {
  norm_by <- match.arg(norm_by)
  stopifnot(all(c(id_col, "concept_name", "score") %in% names(score_df)))

  # Per-document slice membership
  doc_ids <- unique(score_df[[id_col]])
  groups <- list(All = doc_ids)
  if (!is.null(slice_col)) {
    stopifnot(!is.null(slice_df), all(c(id_col, slice_col) %in% names(slice_df)))
    slice_df <- slice_df[!duplicated(slice_df[[id_col]]), , drop = FALSE]
    sl_ids <- as.character(slice_df[[id_col]])
    sl_val <- slice_df[[slice_col]]
    if (is.numeric(sl_val)) {
      breaks <- unique(stats::quantile(sl_val, probs = seq(0, 1, length.out = max_slice_bins + 1), na.rm = TRUE))
      sl_val <- if (length(breaks) > 1) cut(sl_val, breaks = breaks, include.lowest = TRUE) else factor(sl_val)
    }
    sl_val <- as.character(sl_val)
    keep <- sl_ids %in% doc_ids & !is.na(sl_val)
    groups <- c(groups, split(sl_ids[keep], sl_val[keep]))
  }

  # Matches per document x concept; outliers = documents matching nothing
  matched <- score_df[score_df$score >= threshold, c(id_col, "concept_name"), drop = FALSE]
  concept_names <- unique(score_df$concept_name)
  rows <- list()
  for (g in names(groups)) {
    g_ids <- groups[[g]]
    g_matched <- matched[matched[[id_col]] %in% g_ids, , drop = FALSE]
    counts <- table(factor(g_matched$concept_name, levels = concept_names))
    cur <- tibble::tibble(
      slice = g,
      concept = concept_names,
      n = as.integer(counts[concept_names]),
      slice_size = length(g_ids)
    )
    if (include_outlier) {
      n_outlier <- sum(!g_ids %in% g_matched[[id_col]])
      cur <- dplyr::bind_rows(cur, tibble::tibble(
        slice = g, concept = "Outlier", n = n_outlier, slice_size = length(g_ids)
      ))
    }
    rows[[g]] <- cur
  }
  out <- dplyr::bind_rows(rows)

  concept_totals <- out$n[out$slice == "All"]
  names(concept_totals) <- out$concept[out$slice == "All"]
  out$value <- switch(
    norm_by,
    none = out$n,
    slice = ifelse(out$slice_size > 0, out$n / out$slice_size, 0),
    concept = {
      tot <- unname(concept_totals[out$concept])
      ifelse(tot > 0, out$n / tot, 0)
    }
  )
  out
}

#' Heatmap of concept matches by group
#'
#' The lloomr replacement for upstream's interactive matrix widget: a
#' ggplot2 heatmap of concepts (rows) by document groups (columns), where
#' fill encodes how common each concept is in each group and each tile is
#' labeled with the match count. Returns a ggplot object for further
#' customization.
#'
#' @param sess A [lloom_session()] after [lloom_score()].
#' @param slice_col Optional column of the session's data frame to slice
#'   by (e.g. a party or time variable).
#' @param norm_by `"slice"` (default when slicing: fraction of each group's
#'   documents), `"concept"`, or `"none"` (raw counts).
#' @param threshold Minimum score counting as a match. Default 1.
#' @param max_slice_bins Maximum bins for numeric slice columns. Default 5.
#' @param include_outlier Include the "Outlier" row. Default `TRUE`.
#' @return A ggplot object.
#' @export
#' @examples
#' \dontrun{
#' sess <- lloom_score(lloom_gen(lloom_session(df, "text", "doc_id")))
#' lloom_vis(sess, slice_col = "party")
#' # It is a regular ggplot object:
#' lloom_vis(sess) + ggplot2::labs(title = "My title")
#' }
lloom_vis <- function(sess,
                      slice_col = NULL,
                      norm_by = NULL,
                      threshold = 1,
                      max_slice_bins = 5,
                      include_outlier = TRUE) {
  stopifnot(inherits(sess, "lloom_session"))
  if (is.null(sess$score_df)) {
    cli::cli_abort("No scores in session. Run {.fn lloom_score} first.")
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required for {.fn lloom_vis}.")
  }
  norm_by <- norm_by %||% if (is.null(slice_col)) "none" else "slice"

  mat <- concept_matrix(
    sess$score_df, sess$id_col,
    slice_df = sess$df, slice_col = slice_col,
    threshold = threshold, norm_by = norm_by,
    max_slice_bins = max_slice_bins, include_outlier = include_outlier
  )

  # Order: concepts by overall matches (Outlier last); "All" column first
  all_n <- mat[mat$slice == "All", , drop = FALSE]
  concept_order <- all_n$concept[order(all_n$n)]
  concept_order <- c("Outlier"[("Outlier" %in% concept_order)], setdiff(concept_order, "Outlier"))
  mat$concept <- factor(mat$concept, levels = concept_order)
  mat$slice <- factor(mat$slice, levels = c("All", sort(setdiff(unique(mat$slice), "All"))))

  fill_lab <- switch(norm_by,
    none = "Matches",
    slice = "Share of group",
    concept = "Share of concept"
  )
  subtitle <- sprintf(
    "Tile label: number of matching documents (score >= %s)%s",
    format(threshold),
    if (norm_by == "slice") "; fill: share of the group's documents" else ""
  )

  ggplot2::ggplot(mat, ggplot2::aes(x = .data$slice, y = .data$concept, fill = .data$value)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.8) +
    ggplot2::geom_text(ggplot2::aes(label = .data$n), size = 3.4) +
    ggplot2::scale_fill_gradient(low = "white", high = "#82c1fb", name = fill_lab) +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(
      title = "Concept matches by group",
      subtitle = subtitle,
      x = NULL, y = NULL
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = 14, face = "bold"),
      plot.title.position = "plot",
      panel.grid = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 11)
    )
}

#' Export a per-concept results table
#'
#' One row per active concept with its criteria, prevalence, and evidence
#' (replaces upstream `export_df()` / `__get_df_for_export()`).
#'
#' @param sess A [lloom_session()] after [lloom_score()].
#' @param threshold Minimum score counting as a match. Default 1.
#' @param max_highlights Maximum highlight quotes kept per concept.
#'   Default 3 (as upstream).
#' @return A tibble: `concept`, `criteria`, `summary`, `rep_examples`
#'   (list column: the concept's exemplar documents), `prevalence`,
#'   `n_matches`, `highlights` (list column).
#' @export
#' @examples
#' \dontrun{
#' lloom_export(sess)  # after lloom_gen() and lloom_score()
#' }
lloom_export <- function(sess, threshold = 1, max_highlights = 3) {
  stopifnot(inherits(sess, "lloom_session"))
  if (is.null(sess$score_df)) {
    cli::cli_abort("No scores in session. Run {.fn lloom_score} first.")
  }
  concepts <- sess$concepts[sess$concepts$active, , drop = FALSE]
  score_df <- sess$score_df
  n_docs <- length(unique(score_df[[sess$id_col]]))

  rows <- lapply(seq_len(nrow(concepts)), function(i) {
    c_id <- concepts$id[i]
    matched <- score_df[score_df$concept_id == c_id & score_df$score >= threshold, , drop = FALSE]
    highlights <- matched$highlight[!is.na(matched$highlight) & nchar(matched$highlight) > 0]
    if (length(highlights) > max_highlights) {
      highlights <- sample(highlights, max_highlights)
    }
    rep_ex <- character(0)
    if (!is.null(sess$df_filtered)) {
      ex_ids <- concepts$example_ids[[i]]
      src <- sess$df_filtered
      rep_ex <- src[[sess$text_col]][as.character(src[[sess$id_col]]) %in% ex_ids]
    }
    tibble::tibble(
      concept = concepts$name[i],
      criteria = concepts$prompt[i],
      summary = concepts$summary[i],
      rep_examples = list(rep_ex),
      prevalence = round(nrow(matched) / n_docs, 2),
      n_matches = nrow(matched),
      highlights = list(highlights)
    )
  })
  dplyr::bind_rows(rows)
}
