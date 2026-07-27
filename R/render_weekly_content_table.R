weekly_content_weeks <- 1:13
weekly_content_sections <- c("lecture", "workshop", "practical", "extra")

weekly_note_registry <- list(
  resource = list(label = "Resource", icon = "bi-book"),
  quiz = list(label = "Practice quiz (0%)", icon = "bi-check2-square"),
  assessment = list(label = "Assessment", icon = "bi-clipboard-check"),
  notice = list(label = "Notice", icon = "bi-info-circle")
)

weekly_note_types <- names(weekly_note_registry)

read_weekly_content_csv <- function(path) {
  read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = c(note_weight = "character")
  )
}

weekly_row_context <- function(data, index) {
  paste0(
    "week ", data$week[[index]],
    ", position ", data$position[[index]]
  )
}

weekly_url_text_is_valid <- function(value) {
  grepl(
    "^(?:[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=-]|%[0-9A-Fa-f]{2})+$",
    value,
    perl = TRUE
  )
}

weekly_url_authority_is_valid <- function(authority) {
  if (!nzchar(authority)) {
    return(FALSE)
  }

  at_positions <- gregexpr("@", authority, fixed = TRUE)[[1]]
  at_count <- if (at_positions[[1]] == -1L) 0L else length(at_positions)
  if (at_count > 1L) {
    return(FALSE)
  }

  if (at_count == 1L) {
    user_info <- substr(authority, 1L, at_positions[[1]] - 1L)
    if (!nzchar(user_info)) {
      return(FALSE)
    }
    authority <- substr(authority, at_positions[[1]] + 1L, nchar(authority))
  }

  if (grepl("^\\[", authority)) {
    return(grepl(
      "^\\[[0-9A-Fa-f:.]+\\](?::[0-9]{1,5})?$",
      authority,
      perl = TRUE
    ))
  }

  grepl(
    paste0(
      "^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?",
      "(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*",
      "(?::[0-9]{1,5})?$"
    ),
    authority,
    perl = TRUE
  )
}

classify_weekly_url <- function(value) {
  if (is.na(value) || identical(value, "")) {
    return("none")
  }
  if (grepl("[[:space:][:cntrl:]]", value) ||
      grepl("\\", value, fixed = TRUE) ||
      grepl("^//", value) ||
      grepl("^/", value) ||
      !weekly_url_text_is_valid(value)) {
    return(NA_character_)
  }
  if (grepl("^https?://", value)) {
    authority <- sub(
      "^https?://([^/?#]*).*$",
      "\\1",
      value,
      perl = TRUE
    )
    return(if (weekly_url_authority_is_valid(authority)) {
      "external"
    } else {
      NA_character_
    })
  }
  if (grepl(
    paste0(
      "^[A-Za-z0-9._~-]+(?:/[A-Za-z0-9._~-]+)*",
      "(?:\\?(?:[A-Za-z0-9._~:/?@!$&'()*+,;=-]|%[0-9A-Fa-f]{2})*)?",
      "(?:#(?:[A-Za-z0-9._~:/?@!$&'()*+,;=-]|%[0-9A-Fa-f]{2})*)?$"
    ),
    value,
    perl = TRUE
  )) {
    return("internal")
  }
  NA_character_
}

title_has_presentation_markup <- function(value) {
  grepl("<[^>]+>", value) ||
    grepl("\\bbi\\s+bi-", value, perl = TRUE) ||
    grepl("[→↗]", value) ||
    grepl("^(Resource|Practice quiz|Assessment|Notice):", value)
}

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

escape_html_text <- function(value) {
  escape_html_attribute(value)
}

validate_semester_breaks <- function(data) {
  if (is.null(data)) {
    return(invisible(TRUE))
  }

  required_columns <- c("after_week", "title", "start_date", "end_date")
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      "semester_breaks.csv is missing columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  if (nrow(data) == 0) {
    return(invisible(TRUE))
  }

  after_week <- suppressWarnings(as.numeric(data$after_week))
  valid_positions <- weekly_content_weeks[-length(weekly_content_weeks)]
  if (
    anyNA(after_week) ||
      any(after_week != as.integer(after_week)) ||
      any(!after_week %in% valid_positions)
  ) {
    stop(
      "after_week must be a whole-number teaching week before the final week.",
      call. = FALSE
    )
  }

  if (anyNA(data$title) || any(!nzchar(trimws(data$title)))) {
    stop("Every semester break must have a title.", call. = FALSE)
  }

  start_dates <- suppressWarnings(as.Date(
    trimws(data$start_date),
    format = "%Y-%m-%d"
  ))
  end_dates <- suppressWarnings(as.Date(
    trimws(data$end_date),
    format = "%Y-%m-%d"
  ))
  if (anyNA(start_dates) || anyNA(end_dates)) {
    stop(
      "start_date and end_date must use YYYY-MM-DD dates.",
      call. = FALSE
    )
  }
  if (any(end_dates < start_dates)) {
    stop("A semester break cannot end before it starts.", call. = FALSE)
  }

  invisible(TRUE)
}

format_schedule_date_range <- function(start_date, end_date) {
  day <- function(value) as.integer(format(value, "%d"))
  month <- function(value) format(value, "%B")
  year <- function(value) format(value, "%Y")

  if (identical(start_date, end_date)) {
    return(sprintf("%s %s %s", day(start_date), month(start_date), year(start_date)))
  }

  if (year(start_date) == year(end_date)) {
    if (month(start_date) == month(end_date)) {
      return(sprintf(
        "%s–%s %s %s",
        day(start_date), day(end_date), month(start_date), year(start_date)
      ))
    }

    return(sprintf(
      "%s %s–%s %s %s",
      day(start_date), month(start_date),
      day(end_date), month(end_date), year(start_date)
    ))
  }

  sprintf(
    "%s %s %s–%s %s %s",
    day(start_date), month(start_date), year(start_date),
    day(end_date), month(end_date), year(end_date)
  )
}

semester_break_entries <- function(data = NULL) {
  validate_semester_breaks(data)
  if (is.null(data) || nrow(data) == 0) {
    return(list())
  }

  data$after_week <- as.integer(data$after_week)
  data$start_date <- as.Date(trimws(data$start_date), format = "%Y-%m-%d")
  data$end_date <- as.Date(trimws(data$end_date), format = "%Y-%m-%d")
  data <- data[order(data$after_week, data$start_date, data$title), ]

  lapply(seq_len(nrow(data)), function(index) {
    list(
      after_week = data$after_week[[index]],
      title = trimws(data$title[[index]]),
      date_range = format_schedule_date_range(
        data$start_date[[index]],
        data$end_date[[index]]
      )
    )
  })
}

validate_weekly_content <- function(data) {
  required_columns <- c(
    "week", "section", "position", "title", "url", "description",
    "show_on_schedule", "note_type", "note_weight"
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
      "section must be lecture, workshop, practical, or extra.",
      call. = FALSE
    )
  }

  schedule_visibility <- trimws(as.character(data$show_on_schedule))
  if (
    anyNA(data$show_on_schedule) ||
      any(!schedule_visibility %in% c("TRUE", "FALSE"))
  ) {
    stop(
      "show_on_schedule must contain only TRUE or FALSE.",
      call. = FALSE
    )
  }
  if (any(data$section == "workshop" & schedule_visibility != "FALSE")) {
    stop(
      "Workshop rows must set show_on_schedule to FALSE.",
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

  for (index in seq_len(nrow(data))) {
    context <- weekly_row_context(data, index)
    section <- data$section[[index]]
    note_type <- data$note_type[[index]]
    note_weight <- data$note_weight[[index]]
    title <- data$title[[index]]
    url <- data$url[[index]]
    note_weight_text <- if (is.na(note_weight)) {
      ""
    } else {
      as.character(note_weight)
    }

    if (section == "extra") {
      if (is.na(note_type) || !note_type %in% weekly_note_types) {
        stop(
          context,
          ": note_type must be resource, quiz, assessment, or notice.",
          call. = FALSE
        )
      }

      if (identical(note_type, "assessment")) {
        valid_note_weight <- nzchar(note_weight_text) &&
          identical(note_weight_text, trimws(note_weight_text)) &&
          grepl(
            "^(0|[1-9][0-9]?|100)$",
            note_weight_text,
            perl = TRUE
          )
        if (!valid_note_weight) {
          stop(
            context,
            paste0(
              ": note_weight must be a whole number from 0 to 100 ",
              "for assessment Notes."
            ),
            call. = FALSE
          )
        }
      } else if (nzchar(note_weight_text)) {
        stop(
          context,
          ": note_weight must be blank unless note_type is assessment.",
          call. = FALSE
        )
      }
    } else if (!is.na(note_type) && nzchar(note_type)) {
      stop(
        context,
        ": note_type must be blank outside Notes rows.",
        call. = FALSE
      )
    } else if (nzchar(note_weight_text)) {
      stop(
        context,
        ": note_weight must be blank unless note_type is assessment.",
        call. = FALSE
      )
    }

    if (!identical(title, trimws(title)) ||
        title_has_presentation_markup(title)) {
      stop(
        context,
        paste0(
          ": title must contain plain student-facing text without ",
          "surrounding whitespace or presentation markup."
        ),
        call. = FALSE
      )
    }

    if (is.na(classify_weekly_url(url))) {
      stop(
        context,
        ": url must be blank, repository-relative, or a valid HTTP(S) URL.",
        call. = FALSE
      )
    }
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
  data$show_on_schedule <-
    trimws(as.character(data$show_on_schedule)) == "TRUE"
  data <- data[
    order(
      data$week,
      match(data$section, weekly_content_sections),
      data$position
    ),
  ]
  all_data <- data
  data <- data[data$show_on_schedule, , drop = FALSE]

  resources_for <- function(rows, section) {
    rows <- rows[rows$section == section, , drop = FALSE]

    lapply(seq_len(nrow(rows)), function(index) {
      url <- rows$url[[index]]
      description <- rows$description[[index]]
      note_type <- rows$note_type[[index]]
      note_weight <- rows$note_weight[[index]]
      url_kind <- classify_weekly_url(url)

      list(
        title = rows$title[[index]],
        url = if (is.na(url) || !nzchar(url)) NULL else url,
        url_kind = url_kind,
        note_type = if (
          is.na(note_type) || !nzchar(note_type)
        ) NULL else note_type,
        note_weight = if (
          is.na(note_weight) || !nzchar(as.character(note_weight))
        ) NULL else as.integer(note_weight),
        description = if (
          is.na(description) || !nzchar(trimws(description))
        ) NULL else trimws(description)
      )
    })
  }

  lapply(weekly_content_weeks, function(week) {
    all_rows <- all_data[all_data$week == week, , drop = FALSE]
    rows <- data[data$week == week, , drop = FALSE]
    workshop <- resources_for(all_rows, "workshop")
    practical <- resources_for(rows, "practical")

    list(
      week = week,
      lectures = resources_for(rows, "lecture"),
      workshop = if (length(workshop) == 0) NULL else workshop[[1]],
      practical = if (length(practical) == 0) NULL else practical[[1]],
      extras = resources_for(rows, "extra"),
      includes_workshop = length(workshop) > 0
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

weekly_note_definition <- function(resource) {
  weekly_note_registry[[resource$note_type]]
}

weekly_note_link <- function(resource, html_output = FALSE, plain_output = FALSE) {
  title <- escape_markdown_text(resource$title)
  if (is.null(resource$url) || !nzchar(resource$url)) {
    return(title)
  }
  if (plain_output) {
    return(paste0(title, " (", resource$url, ")"))
  }

  classes <- if (html_output && identical(resource$url_kind, "external")) {
    "{.weekly-note-link .is-external}"
  } else if (html_output) {
    "{.weekly-note-link}"
  } else {
    ""
  }
  paste0("[", title, "](<", resource$url, ">)", classes)
}

weekly_note_markdown <- function(
  resource,
  html_output = FALSE,
  plain_output = FALSE
) {
  definition <- weekly_note_definition(resource)
  destination <- weekly_note_link(resource, html_output, plain_output)
  label <- if (identical(resource$note_type, "assessment")) {
    paste0(definition$label, " (", resource$note_weight, "%)")
  } else {
    definition$label
  }

  if (!html_output) {
    return(paste0("**", label, ":** ", destination))
  }

  icon <- paste0(
    "[]{.bi .", definition$icon,
    ' .weekly-note-icon aria-hidden="true"}'
  )
  category <- paste0(
    "[", label, ":]{.weekly-note-category}"
  )
  marker <- if (identical(resource$url_kind, "external")) {
    ' [↗]{.weekly-note-external-marker aria-hidden="true"}'
  } else {
    ""
  }
  content <- paste0(
    "[",
    category,
    " ",
    destination,
    marker,
    "]{.weekly-note-content}"
  )

  paste(icon, content)
}

weekly_note_cell_lines <- function(
  resources,
  html_output,
  plain_output = FALSE
) {
  if (length(resources) == 0) {
    return("  - —")
  }

  items <- vapply(
    resources,
    weekly_note_markdown,
    character(1),
    html_output = html_output,
    plain_output = plain_output
  )

  if (!html_output) {
    return(c("  -", "", paste("    -", items)))
  }

  c(
    "  - ::: {.weekly-note-list}",
    "",
    paste("    -", items),
    "",
    "    :::"
  )
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
  if (length(resources) == 0) {
    return("  - —")
  }

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

practical_cell_line <- function(
  practical,
  workshop,
  html_output,
  week,
  includes_workshop
) {
  if (is.null(practical)) {
    return("  - —")
  }

  if (!html_output) {
    if (is.null(practical$url) || !nzchar(practical$url)) {
      return("  - Practical session")
    }

    return(sprintf("  - [Practical session](%s)", practical$url))
  }

  label <- if (includes_workshop) {
    sprintf(
      "Week %s practical session, including Workshop %s",
      week,
      week
    )
  } else {
    sprintf("Week %s practical session", week)
  }
  session_entry <- if (is.null(workshop)) practical else workshop
  title_text <- if (is.null(workshop)) {
    practical$title
  } else {
    paste0(practical$title, " — starts with ", workshop$title)
  }
  accessible_label <- label
  label <- escape_html_attribute(accessible_label)
  title <- escape_html_attribute(title_text)

  if (is.null(session_entry$url) || !nzchar(session_entry$url)) {
    return(paste0(
      "  - [Practical session]",
      '{.weekly-practical-link .weekly-practical-link-static role="img" ',
      'aria-label="', label, '" title="', title, '"}'
    ))
  }

  paste0(
    "  - [", escape_markdown_label(accessible_label), "](",
    session_entry$url, ' "', title, '")'
  )
}

semester_break_table_lines <- function(entry) {
  c(
    "- - [Break]{.semester-break-row}",
    paste0(
      "  - **", escape_markdown_text(entry$title), "** — ",
      escape_markdown_text(entry$date_range)
    ),
    "  -",
    "  -",
    ""
  )
}

weekly_mobile_resource_html <- function(resource, class_name) {
  title <- escape_html_text(resource$title)
  class_name <- escape_html_attribute(class_name)

  if (is.null(resource$url) || !nzchar(resource$url)) {
    return(sprintf('<span class="%s">%s</span>', class_name, title))
  }

  sprintf(
    '<a class="%s" href="%s">%s</a>',
    class_name,
    escape_html_attribute(resource$url),
    title
  )
}

weekly_mobile_note_html <- function(resource) {
  definition <- weekly_note_definition(resource)
  label <- if (identical(resource$note_type, "assessment")) {
    paste0(definition$label, " (", resource$note_weight, "%)")
  } else {
    definition$label
  }
  destination <- escape_html_text(resource$title)
  if (!is.null(resource$url) && nzchar(resource$url)) {
    destination <- sprintf(
      '<a class="weekly-note-link" href="%s">%s</a>',
      escape_html_attribute(resource$url),
      destination
    )
  }
  external_marker <- if (identical(resource$url_kind, "external")) {
    '<span class="weekly-note-external-marker" aria-hidden="true">↗</span>'
  } else {
    ""
  }

  paste0(
    '<li><span class="bi ', definition$icon,
    ' weekly-note-icon" aria-hidden="true"></span>',
    '<span class="weekly-note-content">',
    '<span class="weekly-note-category">',
    escape_html_text(label), ':</span> ',
    destination, external_marker,
    "</span></li>"
  )
}

weekly_mobile_week_lines <- function(entry) {
  lecture <- if (length(entry$lectures) == 0) NULL else entry$lectures[[1]]
  theme <- if (is.null(lecture)) {
    paste("Week", entry$week)
  } else {
    weekly_mobile_resource_html(lecture, "weekly-mobile-theme")
  }
  description <- if (is.null(lecture) || is.null(lecture$description)) {
    "—"
  } else {
    escape_html_text(lecture$description)
  }

  practical_entry <- if (is.null(entry$workshop)) {
    entry$practical
  } else {
    entry$workshop
  }
  practical_title <- if (is.null(practical_entry)) {
    "—"
  } else {
    title <- paste("Open Week", entry$week, "practical")
    visible_title <- escape_html_text(title)
    destination <- if (
      is.null(practical_entry$url) || !nzchar(practical_entry$url)
    ) {
      paste0(
        '<span class="weekly-mobile-practical-label">',
        visible_title,
        "</span>"
      )
    } else {
      sprintf(
        '<a class="weekly-mobile-practical-link" href="%s">%s</a>',
        escape_html_attribute(practical_entry$url),
        visible_title
      )
    }
    paste0(
      '<span class="weekly-mobile-practical-entry">',
      '<span class="weekly-mobile-practical-icon" aria-hidden="true"></span>',
      destination,
      "</span>"
    )
  }

  note_lines <- if (length(entry$extras) == 0) {
    '<span class="weekly-mobile-empty">—</span>'
  } else {
    c(
      '<ul class="weekly-note-list weekly-mobile-notes">',
      vapply(entry$extras, weekly_mobile_note_html, character(1)),
      "</ul>"
    )
  }

  c(
    sprintf(
      paste0(
        '<section class="weekly-mobile-week" id="mobile-week-%s" ',
        'data-schedule-week="%s" aria-labelledby="mobile-week-%s-title">'
      ),
      entry$week,
      entry$week,
      entry$week
    ),
    paste0(
      '<div class="weekly-mobile-week-number"><span>',
      entry$week,
      '</span><small>Week</small></div>'
    ),
    '<div class="weekly-mobile-week-content">',
    '<div class="weekly-mobile-week-heading">',
    sprintf(
      '<h3 id="mobile-week-%s-title">%s</h3>',
      entry$week,
      theme
    ),
    '<span class="weekly-mobile-current-label" hidden></span>',
    "</div>",
    '<div class="weekly-mobile-item">',
    '<span class="weekly-mobile-item-label">Lectures</span>',
    sprintf(
      '<span class="weekly-mobile-description">%s</span>',
      description
    ),
    "</div>",
    '<div class="weekly-mobile-item">',
    '<span class="weekly-mobile-item-label">Practical</span>',
    practical_title,
    "</div>",
    '<div class="weekly-mobile-item">',
    '<span class="weekly-mobile-item-label">Notes</span>',
    note_lines,
    "</div>",
    "</div>",
    "</section>"
  )
}

weekly_mobile_break_lines <- function(entry) {
  c(
    '<section class="weekly-mobile-break">',
    '<div class="weekly-mobile-break-rail" aria-hidden="true">Break</div>',
    paste0(
      '<p><strong>', escape_html_text(entry$title), "</strong> — ",
      escape_html_text(entry$date_range), "</p>"
    ),
    "</section>"
  )
}

weekly_mobile_schedule_lines <- function(weekly_content, semester_breaks) {
  lines <- c(
    '<div class="weekly-schedule-mobile">',
    '<div class="weekly-mobile-header">',
    "<h2>Weekly schedule</h2>",
    paste0(
      '<a class="weekly-current-week-jump" href="#mobile-week-1" hidden>',
      'Jump to current week <span aria-hidden="true">↓</span></a>'
    ),
    "</div>"
  )

  for (entry in weekly_content) {
    lines <- c(lines, weekly_mobile_week_lines(entry))

    breaks_after_week <- Filter(
      function(break_entry) break_entry$after_week == entry$week,
      semester_breaks
    )
    for (break_entry in breaks_after_week) {
      lines <- c(lines, weekly_mobile_break_lines(break_entry))
    }
  }

  c(lines, "</div>")
}

weekly_table_lines <- function(
  weekly_content,
  semester_breaks,
  caption,
  html_output,
  plain_output = FALSE
) {
  lines <- c(
    '::: {#tbl-weekly-content .list-table}',
    caption,
    "",
    "- - Week",
    "  - Lectures",
    "  - Practical",
    "  - Notes",
    ""
  )

  for (entry in weekly_content) {
    lines <- c(
      lines,
      sprintf("- - %s", entry$week),
      lecture_theme_cell_lines(entry$lectures),
      practical_cell_line(
        entry$practical,
        entry$workshop,
        html_output,
        entry$week,
        entry$includes_workshop
      ),
      weekly_note_cell_lines(
        entry$extras,
        html_output,
        plain_output
      ),
      ""
    )

    breaks_after_week <- Filter(
      function(break_entry) break_entry$after_week == entry$week,
      semester_breaks
    )
    for (break_entry in breaks_after_week) {
      lines <- c(
        lines,
        semester_break_table_lines(break_entry)
      )
    }
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
  if (length(resources) == 0) {
    return("—")
  }

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

semester_break_typst_lines <- function(entry) {
  c(
    paste0("### ", escape_markdown_text(entry$title)),
    "",
    escape_markdown_text(entry$date_range),
    ""
  )
}

weekly_typst_schedule_lines <- function(weekly_content, semester_breaks) {
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
      "**Practical session**",
      "",
      schedule_practical_line(entry$practical),
      "",
      "**Notes**",
      "",
      vapply(
        entry$extras,
        function(resource) {
          paste(
            "-",
            weekly_note_markdown(resource, html_output = FALSE)
          )
        },
        character(1)
      ),
      ""
    )

    breaks_after_week <- Filter(
      function(break_entry) break_entry$after_week == entry$week,
      semester_breaks
    )
    for (break_entry in breaks_after_week) {
      lines <- c(lines, semester_break_typst_lines(break_entry))
    }
  }

  lines
}

render_weekly_content_table <- function(
  weekly_content,
  semester_breaks = NULL,
  caption = "BEDA weekly content"
) {
  caption <- if (identical(caption, FALSE)) character() else caption

  weekly_content <- weekly_content_entries(weekly_content)
  semester_breaks <- semester_break_entries(semester_breaks)
  pandoc_to <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  if (is.null(pandoc_to)) {
    pandoc_to <- ""
  }
  html_output <- grepl("^html", pandoc_to)
  plain_output <- identical(pandoc_to, "plain")

  if (identical(pandoc_to, "typst")) {
    lines <- weekly_typst_schedule_lines(weekly_content, semester_breaks)
  } else {
    lines <- weekly_table_lines(
      weekly_content,
      semester_breaks,
      caption,
      html_output,
      plain_output
    )
    if (html_output) {
      lines <- c(
        '::: {.weekly-schedule-desktop .table-responsive tabindex="0"}',
        "",
        lines,
        "",
        ":::",
        "",
        weekly_mobile_schedule_lines(weekly_content, semester_breaks)
      )
    }
  }

  cat(paste(lines, collapse = "\n"), "\n")
}
