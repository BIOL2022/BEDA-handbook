weekly_content_weeks <- 1:13
weekly_content_sections <- c("lecture", "practical", "extra")

escape_markdown_label <- function(value) {
  value <- gsub("\\", "\\\\", value, fixed = TRUE)
  value <- gsub("[", "\\[", value, fixed = TRUE)
  gsub("]", "\\]", value, fixed = TRUE)
}

escape_markdown_text <- function(value) {
  value <- gsub("\\", "\\\\", value, fixed = TRUE)
  punctuation <- strsplit(
    "!\"#$%&'()*+,-./:;<=>?@[]^_`{|}~",
    "",
    fixed = TRUE
  )[[1]]

  for (character in punctuation) {
    value <- gsub(
      character,
      paste0("\\", character),
      value,
      fixed = TRUE
    )
  }

  value
}

escape_html_attribute <- function(value) {
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  gsub(">", "&gt;", value, fixed = TRUE)
}

validate_weekly_content <- function(data) {
  required_columns <- c(
    "week", "section", "position", "title", "url", "description"
  )
  missing_columns <- setdiff(required_columns, names(data))

  if (length(missing_columns) > 0) {
    stop(
      "weekly_content.csv is missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  if (nrow(data) == 0) {
    stop("weekly_content.csv has no resources.", call. = FALSE)
  }

  weeks <- suppressWarnings(as.numeric(data$week))
  if (
    anyNA(weeks) ||
    any(weeks != as.integer(weeks)) ||
    !identical(sort(unique(as.integer(weeks))), weekly_content_weeks)
  ) {
    stop("week must contain whole numbers from 1 to 13.", call. = FALSE)
  }

  if (
    anyNA(data$section) ||
      any(!data$section %in% weekly_content_sections)
  ) {
    stop(
      "section must be lecture, practical, or extra.",
      call. = FALSE
    )
  }

  positions <- suppressWarnings(as.numeric(data$position))
  if (
    anyNA(positions) ||
    any(positions != as.integer(positions)) ||
    any(positions < 1)
  ) {
    stop("position must contain positive whole numbers.", call. = FALSE)
  }

  if (anyNA(data$title) || any(!nzchar(trimws(data$title)))) {
    stop("Every resource must have a title.", call. = FALSE)
  }

  lecture_descriptions <- data$description[data$section == "lecture"]
  if (
    anyNA(lecture_descriptions) ||
      any(!nzchar(trimws(lecture_descriptions)))
  ) {
    stop("Every lecture theme must have a description.", call. = FALSE)
  }

  resource_key <- paste(data$week, data$section, data$position, sep = ":")
  if (anyDuplicated(resource_key)) {
    stop(
      "Each week, section, and position combination must be unique.",
      call. = FALSE
    )
  }

  practical_counts <- table(data$week[data$section == "practical"])
  if (length(practical_counts) > 0 && any(practical_counts > 1)) {
    stop("Each week can have at most one practical.", call. = FALSE)
  }

  lecture_counts <- table(
    factor(
      data$week[data$section == "lecture"],
      levels = weekly_content_weeks
    )
  )
  if (any(lecture_counts != 1)) {
    stop("Each week must have exactly one lecture theme.", call. = FALSE)
  }

  invisible(TRUE)
}

weekly_content_entries <- function(data) {
  validate_weekly_content(data)

  data$week <- as.integer(data$week)
  data$position <- as.integer(data$position)
  data <- data[
    order(
      data$week,
      match(data$section, weekly_content_sections),
      data$position
    ),
  ]

  resources_for <- function(rows, section) {
    rows <- rows[rows$section == section, , drop = FALSE]

    lapply(seq_len(nrow(rows)), function(index) {
      url <- rows$url[[index]]
      description <- rows$description[[index]]

      list(
        title = rows$title[[index]],
        url = if (is.na(url) || !nzchar(url)) NULL else url,
        description = if (
          is.na(description) || !nzchar(trimws(description))
        ) NULL else trimws(description)
      )
    })
  }

  lapply(weekly_content_weeks, function(week) {
    rows <- data[data$week == week, , drop = FALSE]
    practical <- resources_for(rows, "practical")

    list(
      week = week,
      lectures = resources_for(rows, "lecture"),
      practical = if (length(practical) == 0) NULL else practical[[1]],
      extras = resources_for(rows, "extra")
    )
  })
}

resource_markdown <- function(resource) {
  label <- escape_markdown_label(resource$title)

  if (is.null(resource$url) || !nzchar(resource$url)) {
    return(label)
  }

  sprintf("[%s](%s)", label, resource$url)
}

resource_cell_lines <- function(resources) {
  if (length(resources) == 0) {
    return("  - —")
  }

  c(
    "  -",
    "",
    vapply(
      resources,
      function(resource) paste("    -", resource_markdown(resource)),
      character(1)
    )
  )
}

lecture_theme_cell_lines <- function(resources) {
  resource <- resources[[1]]
  c(
    paste("  -", resource_markdown(resource)),
    paste0(
      "    [",
      escape_markdown_text(resource$description),
      "]{.weekly-lecture-description}"
    )
  )
}

practical_cell_line <- function(practical, html_output) {
  if (is.null(practical)) {
    return("  - —")
  }

  if (!html_output) {
    if (is.null(practical$url) || !nzchar(practical$url)) {
      return("  - Practical")
    }

    return(sprintf("  - [Practical](%s)", practical$url))
  }

  label <- escape_html_attribute(practical$title)
  icon <- paste0(
    '<i class="bi bi-flask" aria-hidden="true"></i>',
    '<span class="visually-hidden">', label, "</span>"
  )

  if (is.null(practical$url) || !nzchar(practical$url)) {
    return(paste0(
      '  - <span class="weekly-practical-link weekly-practical-link-static" ',
      'role="img" aria-label="', label, '" title="', label, '">',
      icon,
      "</span>"
    ))
  }

  paste0(
    '  - <a class="weekly-practical-link" href="',
    escape_html_attribute(practical$url),
    '" aria-label="', label, '" title="', label, '">',
    icon,
    "</a>"
  )
}

weekly_table_lines <- function(weekly_content, caption, html_output) {
  lines <- c(
    '::: {#tbl-weekly-content .list-table}',
    caption,
    "",
    "- - Week",
    "  - Lectures",
    "  - Practical",
    "  - Extras",
    ""
  )

  for (entry in weekly_content) {
    lines <- c(
      lines,
      sprintf("- - %s", entry$week),
      lecture_theme_cell_lines(entry$lectures),
      practical_cell_line(entry$practical, html_output),
      resource_cell_lines(entry$extras),
      ""
    )
  }

  lines <- c(lines, ":::")
  lines
}

schedule_resource_lines <- function(resources) {
  if (length(resources) == 0) {
    return("—")
  }

  vapply(
    resources,
    function(resource) paste("-", resource_markdown(resource)),
    character(1)
  )
}

schedule_lecture_lines <- function(resources) {
  resource <- resources[[1]]
  c(
    paste("-", resource_markdown(resource)),
    paste("  ", escape_markdown_text(resource$description))
  )
}

schedule_practical_line <- function(practical) {
  if (is.null(practical)) {
    return("—")
  }

  resource_markdown(practical)
}

weekly_typst_schedule_lines <- function(weekly_content) {
  lines <- c("## Weekly schedule", "")

  for (entry in weekly_content) {
    lines <- c(
      lines,
      sprintf("### Week %s", entry$week),
      "",
      "**Lectures**",
      "",
      schedule_lecture_lines(entry$lectures),
      "",
      "**Practical**",
      "",
      schedule_practical_line(entry$practical),
      "",
      "**Extras**",
      "",
      schedule_resource_lines(entry$extras),
      ""
    )
  }

  lines
}

render_weekly_content_table <- function(
  weekly_content,
  caption = "BEDA weekly content"
) {
  caption <- if (identical(caption, FALSE)) character() else caption

  weekly_content <- weekly_content_entries(weekly_content)
  pandoc_to <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  if (is.null(pandoc_to)) {
    pandoc_to <- ""
  }
  html_output <- grepl("^html", pandoc_to)

  if (identical(pandoc_to, "typst")) {
    lines <- weekly_typst_schedule_lines(weekly_content)
  } else {
    lines <- weekly_table_lines(
      weekly_content,
      caption,
      html_output
    )
  }

  cat(paste(lines, collapse = "\n"), "\n")
}
