#!/usr/bin/env Rscript

script_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
script_file <- normalizePath(sub("^--file=", "", script_argument[[1]]))
repo_root <- normalizePath(file.path(dirname(script_file), ".."))
setwd(repo_root)

source("R/render_weekly_content_table.R")

weekly_content <- read_weekly_content_csv("data/weekly_content.csv")
semester_breaks <- read.csv(
  "data/semester_breaks.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
week_one_description <- weekly_content$description[
  weekly_content$week == 1 & weekly_content$section == "lecture"
][[1]]
week_one_escaped_description <- escape_markdown_text(week_one_description)
timeline_css <- paste(
  readLines("assets/timeline.css", warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)
quarto_config <- paste(
  readLines("_quarto.yml", warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)
semester_status_script <- paste(
  readLines("scripts/semester-status.js", warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)
weekly_schedule_partial <- paste(
  readLines("_partials/weekly-schedule.qmd", warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)

checks <- 0L

expect_true <- function(condition, message) {
  checks <<- checks + 1L
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

expect_error <- function(expression, pattern, message) {
  error <- tryCatch(
    {
      force(expression)
      NULL
    },
    error = identity
  )

  expect_true(inherits(error, "error"), message)
  expect_true(
    grepl(pattern, conditionMessage(error), fixed = TRUE),
    paste(message, "Unexpected error:", conditionMessage(error))
  )
}

render_output <- function(
  pandoc_to,
  caption,
  include_caption = TRUE,
  data = weekly_content,
  breaks = semester_breaks
) {
  previous_output <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(
    knitr::opts_knit$set(rmarkdown.pandoc.to = previous_output),
    add = TRUE
  )
  knitr::opts_knit$set(rmarkdown.pandoc.to = pandoc_to)

  arguments <- list(
    weekly_content = data,
    semester_breaks = breaks
  )
  if (include_caption) {
    arguments$caption <- caption
  }

  capture.output(do.call(render_weekly_content_table, arguments))
}

run_pandoc <- function(to, input) {
  output <- system2(
    "quarto",
    c("pandoc", "--from=markdown", paste0("--to=", to), "--wrap=none"),
    input = input,
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_true(status == 0L, paste("Pandoc should convert the snippet to", to))
  output
}

count_fixed_matches <- function(value, pattern) {
  matches <- gregexpr(
    pattern,
    paste(value, collapse = "\n"),
    fixed = TRUE
  )[[1]]
  if (identical(matches, -1L)) 0L else length(matches)
}

adversarial_description <- paste0(
  "<em>HTML</em> &copy; $math$ ~~strikeout~~ [brackets] {braces} ",
  "backslash \\ backticks `code` underscores _text_ asterisks *text*"
)
adversarial_snippet <- paste0(
  "[",
  escape_markdown_text(adversarial_description),
  "]{.weekly-lecture-description}"
)
adversarial_ast <- run_pandoc("json", adversarial_snippet)
for (node_type in c("RawInline", "Math", "Strikeout", "Code")) {
  expect_true(
    !any(grepl(paste0('"t":"', node_type, '"'), adversarial_ast, fixed = TRUE)),
    paste("Escaped descriptions should not produce", node_type, "nodes.")
  )
}
adversarial_plain <- run_pandoc("plain", adversarial_snippet)
expect_true(
  identical(paste(adversarial_plain, collapse = "\n"), adversarial_description),
  "Pandoc plain output should preserve the adversarial description exactly."
)

expect_true(
  isTRUE(validate_weekly_content(weekly_content)),
  "The maintained weekly content should validate."
)
expect_true(
  isTRUE(validate_semester_breaks(semester_breaks)),
  "The maintained semester breaks should validate."
)

note_rows <- which(weekly_content$section == "extra")
non_note_rows <- which(weekly_content$section != "extra")
first_note_row <- note_rows[[1]]
assessment_rows <- note_rows[weekly_content$note_type[note_rows] == "assessment"]
first_assessment_row <- assessment_rows[[1]]

note_url_cases <- c(
  "https://example.org/)[Injected](javascript:alert(1)",
  "https://example.org/a_(b)",
  "https://example.org/a_(b"
)
for (value in note_url_cases) {
  url_data <- weekly_content
  url_data$url[[first_note_row]] <- value
  expect_true(
    isTRUE(validate_weekly_content(url_data)),
    paste("Notes URL punctuation should remain valid:", shQuote(value))
  )

  url_resource <- weekly_content_entries(url_data)[[1]]$extras[[1]]
  url_ast <- run_pandoc(
    "json",
    weekly_note_markdown(url_resource, html_output = FALSE)
  )
  expected_destination <- gsub("[", "%5B", value, fixed = TRUE)
  expected_destination <- gsub("]", "%5D", expected_destination, fixed = TRUE)
  expect_true(
    count_fixed_matches(url_ast, '"t":"Link"') == 1L &&
      any(grepl(expected_destination, url_ast, fixed = TRUE)),
    paste("Notes URL should produce one intact link:", shQuote(value))
  )
  expect_true(
    !any(grepl('"javascript:', url_ast, fixed = TRUE)),
    paste("Notes URL should not create a javascript destination:", shQuote(value))
  )
}

note_title_cases <- c(
  "*Important* update",
  "`R` output",
  "$p$ value",
  "~~Old~~ new"
)
for (value in note_title_cases) {
  title_data <- weekly_content
  title_data$title[[first_note_row]] <- value
  expect_true(
    isTRUE(validate_weekly_content(title_data)),
    paste("Literal Notes title should remain valid:", shQuote(value))
  )

  title_resource <- weekly_content_entries(title_data)[[1]]$extras[[1]]
  title_markdown <- weekly_note_markdown(
    title_resource,
    html_output = FALSE
  )
  title_ast <- run_pandoc("json", title_markdown)
  for (node_type in c("Emph", "Code", "Math", "Strikeout")) {
    expect_true(
      !any(grepl(
        paste0('"t":"', node_type, '"'),
        title_ast,
        fixed = TRUE
      )),
      paste("Literal Notes title should not produce", node_type, "nodes.")
    )
  }

  title_html <- run_pandoc("html", title_markdown)
  expect_true(
    any(grepl(value, title_html, fixed = TRUE)),
    paste("Rendered HTML should preserve the literal Notes title:", shQuote(value))
  )
}

expect_true(
  identical(
    weekly_note_registry,
    list(
      resource = list(label = "Resource", icon = "bi-book"),
      quiz = list(label = "Practice quiz (0%)", icon = "bi-check2-square"),
      assessment = list(label = "Assessment", icon = "bi-clipboard-check"),
      notice = list(label = "Notice", icon = "bi-info-circle")
    )
  ),
  "The Notes registry should cover the four supported categories."
)

missing_note_type <- weekly_content
missing_note_type$note_type <- NULL
expect_error(
  validate_weekly_content(missing_note_type),
  "weekly_content.csv is missing columns: note_type",
  "A missing note_type column should be rejected."
)

missing_note_weight <- weekly_content
missing_note_weight$note_weight <- NULL
expect_error(
  validate_weekly_content(missing_note_weight),
  "weekly_content.csv is missing columns: note_weight",
  "A missing note_weight column should be rejected."
)

for (invalid_value in c("", " ", "Resource", " resource", "resource ", "other")) {
  invalid_note_type <- weekly_content
  invalid_note_type$note_type[[first_note_row]] <- invalid_value
  expect_error(
    validate_weekly_content(invalid_note_type),
    paste0(
      "week ", invalid_note_type$week[[first_note_row]],
      ", position ", invalid_note_type$position[[first_note_row]]
    ),
    paste("Invalid note_type should identify its row:", shQuote(invalid_value))
  )
}

misplaced_note_type <- weekly_content
misplaced_note_type$note_type[[non_note_rows[[1]]]] <- "notice"
expect_error(
  validate_weekly_content(misplaced_note_type),
  paste0(
    "week ", misplaced_note_type$week[[non_note_rows[[1]]]],
    ", position ", misplaced_note_type$position[[non_note_rows[[1]]]]
  ),
  "A note_type on a non-Notes row should be rejected."
)

for (invalid_value in list(
  NA,
  "",
  " ",
  -1,
  101,
  5.5,
  "five",
  "05",
  "5%"
)) {
  invalid_note_weight <- weekly_content
  invalid_note_weight$note_weight[[first_assessment_row]] <- invalid_value
  expect_error(
    validate_weekly_content(invalid_note_weight),
    paste0(
      "week ", invalid_note_weight$week[[first_assessment_row]],
      ", position ", invalid_note_weight$position[[first_assessment_row]]
    ),
    paste(
      "Invalid assessment note_weight should identify its row:",
      shQuote(invalid_value)
    )
  )
}

for (valid_value in c(0, 100)) {
  valid_note_weight <- weekly_content
  valid_note_weight$note_weight[[first_assessment_row]] <- valid_value
  expect_true(
    isTRUE(validate_weekly_content(valid_note_weight)),
    paste("Whole assessment note_weight should be accepted:", valid_value)
  )
}

read_authored_note_weight <- function(value) {
  csv_lines <- readLines(
    "data/weekly_content.csv",
    warn = FALSE,
    encoding = "UTF-8"
  )
  target_line <- grep("^4,extra,1,", csv_lines)
  stopifnot(length(target_line) == 1L)
  csv_lines[[target_line]] <- sub(
    ",assessment,5$",
    paste0(",assessment,", value),
    csv_lines[[target_line]]
  )

  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(csv_lines, path, useBytes = TRUE)
  read_weekly_content_csv(path)
}

for (authored_value in c("05", " 5", "5e1")) {
  authored_weight <- read_authored_note_weight(authored_value)
  expect_true(
    identical(
      authored_weight$note_weight[[first_assessment_row]],
      authored_value
    ),
    paste("The CSV loader should preserve note_weight:", shQuote(authored_value))
  )
  expect_error(
    validate_weekly_content(authored_weight),
    "week 4, position 1",
    paste(
      "Authored note_weight should be rejected without normalisation:",
      shQuote(authored_value)
    )
  )
}

for (authored_value in c("0", "100")) {
  authored_weight <- read_authored_note_weight(authored_value)
  expect_true(
    identical(
      authored_weight$note_weight[[first_assessment_row]],
      authored_value
    ) && isTRUE(validate_weekly_content(authored_weight)),
    paste(
      "The CSV loader should preserve and accept note_weight:",
      shQuote(authored_value)
    )
  )
}

for (row in c(
  note_rows[weekly_content$note_type[note_rows] != "assessment"][[1]],
  non_note_rows[[1]]
)) {
  misplaced_note_weight <- weekly_content
  misplaced_note_weight$note_weight[[row]] <- 5
  expect_error(
    validate_weekly_content(misplaced_note_weight),
    paste0(
      "week ", misplaced_note_weight$week[[row]],
      ", position ", misplaced_note_weight$position[[row]]
    ),
    "note_weight outside an Assessment row should be rejected."
  )
}

valid_note_urls <- c(
  "",
  "prerequisites.qmd",
  "module02/202-timeline.qmd#wk6",
  "page.qmd?x=hello%20world",
  "https://canvas.sydney.edu.au/courses/74353",
  "https://example.com/a%20path?x=hello%20world#part"
)
for (value in valid_note_urls) {
  valid_url_data <- weekly_content
  valid_url_data$url[[first_note_row]] <- value
  expect_true(
    isTRUE(validate_weekly_content(valid_url_data)),
    paste("Valid Notes URL should be accepted:", shQuote(value))
  )
}

invalid_note_urls <- c(
  " prerequisites.qmd",
  "prerequisites.qmd ",
  "javascript:alert(1)",
  "//example.com/path",
  "/absolute/path.qmd",
  "C:\\temp\\page.qmd",
  "https://example.com/path with space",
  "https://example.com/a?x=hello world",
  "page.qmd?x=hello world",
  "page.qmd?x=<script>",
  "https://:443/path",
  "https://user@/path",
  "https:///missing-host",
  paste0("page.qmd", intToUtf8(1))
)
for (value in invalid_note_urls) {
  invalid_url_data <- weekly_content
  invalid_url_data$url[[first_note_row]] <- value
  expect_error(
    validate_weekly_content(invalid_url_data),
    paste0(
      "week ", invalid_url_data$week[[first_note_row]],
      ", position ", invalid_url_data$position[[first_note_row]]
    ),
    paste("Invalid Notes URL should identify its row:", shQuote(value))
  )
}

invalid_note_titles <- c(
  " Leading whitespace",
  "Trailing whitespace ",
  "<i>Literal tag</i>",
  "bi bi-book Bootstrap icon",
  "Destination arrow →",
  "Destination arrow ↗",
  "Resource: Prefixed category",
  "Practice quiz: Prefixed category"
)
for (value in invalid_note_titles) {
  invalid_title_data <- weekly_content
  invalid_title_data$title[[first_note_row]] <- value
  expect_error(
    validate_weekly_content(invalid_title_data),
    paste0(
      "week ", invalid_title_data$week[[first_note_row]],
      ", position ", invalid_title_data$position[[first_note_row]]
    ),
    paste("Invalid Notes title should identify its row:", shQuote(value))
  )
}

punctuated_note_title <- weekly_content
punctuated_note_title$title[[first_note_row]] <-
  "Students' guide: Report 1 (25%) — overview"
expect_true(
  isTRUE(validate_weekly_content(punctuated_note_title)),
  "Ordinary punctuation in a Notes title should be accepted."
)

expected_note_types <- c(
  "1:1" = "resource", "1:2" = "quiz", "1:3" = "notice",
  "2:1" = "resource", "2:2" = "quiz",
  "3:1" = "quiz", "3:2" = "notice",
  "4:1" = "assessment",
  "5:1" = "assessment", "5:2" = "notice",
  "6:1" = "notice",
  "8:1" = "assessment",
  "9:1" = "notice",
  "10:1" = "notice", "10:2" = "notice",
  "11:1" = "assessment",
  "13:1" = "assessment"
)
expected_note_titles <- c(
  "1:1" = "Am I ready for BEDA?",
  "1:2" = "Quiz 1",
  "1:3" = "Snail-collecting competition: prizes to be won",
  "2:1" = "Common statistical tests are linear models",
  "2:2" = "Quiz 2",
  "3:1" = "Quiz 3",
  "3:2" = "Early Feedback Task opens Friday 21 August at 10:00",
  "4:1" = "Early Feedback Task due Friday 28 August at 23:59",
  "5:1" = "Evaluation Quiz due Friday 4 September at 23:59",
  "5:2" = "Begin working on Report 1",
  "8:1" = "Report 1 due Friday 25 September at 23:59",
  "9:1" = "Labour Day — Monday 5 October",
  "10:1" = "Present your experimental design for feedback",
  "10:2" = "Prepare for Report 2",
  "11:1" = "Report 2 group dataset due at 10:00 on your practical day",
  "13:1" = "Report 2 individual report due Friday 6 November at 23:59"
)
expected_note_weights <- c(
  "4:1" = 5L,
  "5:1" = 10L,
  "8:1" = 25L,
  "11:1" = 5L,
  "13:1" = 15L
)
note_keys <- paste(
  weekly_content$week[note_rows],
  weekly_content$position[note_rows],
  sep = ":"
)
expect_true(
  length(note_rows) == 16L,
  "The maintained schedule should contain exactly 16 Notes rows."
)
expect_true(
  identical(
    unname(weekly_content$note_type[note_rows]),
    unname(expected_note_types[note_keys])
  ),
  "All 16 Notes rows should match the approved taxonomy."
)
expect_true(
  identical(
    unname(weekly_content$title[note_rows]),
    unname(expected_note_titles[note_keys])
  ),
  "All 16 Notes rows should use the approved final titles."
)
expect_true(
  identical(
    as.integer(weekly_content$note_weight[assessment_rows]),
    unname(expected_note_weights[note_keys[
      weekly_content$note_type[note_rows] == "assessment"
    ]])
  ),
  "Assessment Notes should use the approved weights."
)
expect_true(
  all(
    is.na(weekly_content$note_weight[-assessment_rows]) |
      weekly_content$note_weight[-assessment_rows] == ""
  ),
  "note_weight should be blank outside Assessment Notes."
)
expect_true(
  all(
    is.na(weekly_content$note_type[non_note_rows]) |
      weekly_content$note_type[non_note_rows] == ""
  ),
  "Rows outside Notes should have a blank note_type."
)

invalid_break_position <- semester_breaks
invalid_break_position$after_week[[1]] <- 13
expect_error(
  validate_semester_breaks(invalid_break_position),
  "after_week must be a whole-number teaching week before the final week.",
  "A semester break must be placed between teaching weeks."
)

invalid_break_date <- semester_breaks
invalid_break_date$start_date[[1]] <- "28 September 2026"
expect_error(
  validate_semester_breaks(invalid_break_date),
  "start_date and end_date must use YYYY-MM-DD dates.",
  "Semester break dates should use an editable ISO format."
)

entries <- weekly_content_entries(weekly_content)
expect_true(length(entries) == 13, "The renderer should create 13 weeks.")
expect_true(
  identical(vapply(entries, `[[`, integer(1), "week"), 1:13),
  "Weeks should be ordered from 1 to 13."
)
expect_true(
  is.null(entries[[1]]$workshop) &&
    identical(entries[[1]]$practical$url, "module01/102-week01.qmd"),
  "Week 1 should use the combined practical page as its session entry point."
)
expect_true(
  is.null(entries[[2]]$workshop),
  "A week without a workshop should not gain a workshop entry point."
)
expect_true(
  identical(entries[[1]]$extras[[1]]$note_type, "resource"),
  "Resource objects should retain their note_type."
)
expect_true(
  is.null(entries[[1]]$extras[[1]]$note_weight) &&
    is.null(entries[[1]]$extras[[2]]$note_weight),
  "Resource and Practice quiz objects should retain blank weights."
)
expect_true(
  identical(entries[[1]]$extras[[1]]$url_kind, "internal"),
  "Repository-relative Notes links should be classified as internal."
)
expect_true(
  identical(entries[[1]]$extras[[2]]$url_kind, "none"),
  "Unlinked Notes should be classified as none."
)
expect_true(
  identical(entries[[2]]$extras[[1]]$url_kind, "external"),
  "HTTP(S) Notes links should be classified as external."
)

missing_column <- weekly_content
missing_column$url <- NULL
expect_error(
  validate_weekly_content(missing_column),
  "missing columns",
  "Missing columns should be rejected."
)

missing_description <- weekly_content
missing_description$description <- NULL
expect_error(
  validate_weekly_content(missing_description),
  "missing columns: description",
  "A missing description column should be rejected."
)

missing_visibility <- weekly_content
missing_visibility$show_on_schedule <- NULL
expect_error(
  validate_weekly_content(missing_visibility),
  "missing columns: show_on_schedule",
  "A missing schedule-visibility column should be rejected."
)

for (invalid_visibility in list("", " ", NA_character_, "true", "yes")) {
  invalid_visibility_data <- weekly_content
  invalid_visibility_data$show_on_schedule <- as.character(
    invalid_visibility_data$show_on_schedule
  )
  invalid_visibility_data$show_on_schedule[[1]] <- invalid_visibility
  expect_error(
    validate_weekly_content(invalid_visibility_data),
    "show_on_schedule must contain only TRUE or FALSE",
    "Blank, missing, lowercase, and invalid visibility values should be rejected."
  )
}

visible_workshop <- weekly_content
workshop_row <- which(visible_workshop$section == "practical")[[1]]
visible_workshop$section[[workshop_row]] <- "workshop"
visible_workshop$show_on_schedule[[workshop_row]] <- TRUE
expect_error(
  validate_weekly_content(visible_workshop),
  "Workshop rows must set show_on_schedule to FALSE",
  "Workshop rows should be explicitly hidden from the schedule."
)

hidden_lecture <- weekly_content
hidden_lecture_row <- which(hidden_lecture$section == "lecture")[[1]]
hidden_lecture$show_on_schedule[[hidden_lecture_row]] <- FALSE
expect_true(
  isTRUE(validate_weekly_content(hidden_lecture)),
  "A lecture may be explicitly hidden from the schedule."
)
hidden_lecture_entries <- weekly_content_entries(hidden_lecture)
expect_true(
  length(hidden_lecture_entries[[1]]$lectures) == 0L,
  "A hidden lecture should be absent from the Week 1 schedule entry."
)
hidden_lecture_output <- render_output(
  "html",
  caption = FALSE,
  data = hidden_lecture
)
expect_true(
  !any(grepl(
    escape_markdown_label(weekly_content$title[[hidden_lecture_row]]),
    hidden_lecture_output,
    fixed = TRUE
  )),
  "A hidden lecture should be absent from the rendered schedule."
)

blank_lecture_description <- weekly_content
lecture_row <- which(blank_lecture_description$section == "lecture")[[1]]
blank_lecture_description$description[[lecture_row]] <- " "
expect_error(
  validate_weekly_content(blank_lecture_description),
  "Every lecture theme must have a description",
  "Blank lecture descriptions should be rejected."
)

empty_lecture_description <- weekly_content
empty_lecture_description$description[[lecture_row]] <- ""
expect_error(
  validate_weekly_content(empty_lecture_description),
  "Every lecture theme must have a description",
  "Empty lecture descriptions should be rejected."
)

missing_lecture_description <- weekly_content
missing_lecture_description$description[[lecture_row]] <- NA_character_
expect_error(
  validate_weekly_content(missing_lecture_description),
  "Every lecture theme must have a description",
  "Missing lecture descriptions should be rejected."
)

padded_lecture_description <- weekly_content
padded_lecture_description$description[[lecture_row]] <-
  "  Trimmed lecture description.  "
expect_true(
  isTRUE(validate_weekly_content(padded_lecture_description)),
  "Padded lecture descriptions should validate."
)
padded_entries <- weekly_content_entries(padded_lecture_description)
expect_true(
  identical(
    padded_entries[[1]]$lectures[[1]]$description,
    "Trimmed lecture description."
  ),
  "Lecture descriptions should be trimmed in resource objects."
)

blank_nonlecture_descriptions <- weekly_content
blank_nonlecture_descriptions$description[
  blank_nonlecture_descriptions$section != "lecture"
] <- ""
expect_true(
  isTRUE(validate_weekly_content(blank_nonlecture_descriptions)),
  "Practicals and extras may have blank descriptions."
)

nonlecture_description_cases <- weekly_content
practical_row <- which(nonlecture_description_cases$section == "practical")[[1]]
extra_rows <- which(nonlecture_description_cases$section == "extra")[1:2]
nonlecture_description_cases$description[[practical_row]] <- ""
nonlecture_description_cases$description[[extra_rows[[1]]]] <- " "
nonlecture_description_cases$description[[extra_rows[[2]]]] <- NA_character_
nonlecture_entries <- weekly_content_entries(nonlecture_description_cases)
nonlecture_resources <- c(
  list(nonlecture_entries[[1]]$practical),
  nonlecture_entries[[1]]$extras[1:2]
)
for (resource in nonlecture_resources) {
  expect_true(
    "description" %in% names(resource) && is.null(resource$description),
    "Blank nonlecture descriptions should be named NULL values."
  )
}

expect_error(
  validate_weekly_content(weekly_content[0, , drop = FALSE]),
  "has no resources",
  "Empty content should be rejected."
)

invalid_week <- weekly_content
invalid_week$week[[1]] <- 14
expect_error(
  validate_weekly_content(invalid_week),
  "whole numbers from 1 to 13",
  "Invalid weeks should be rejected."
)

invalid_section <- weekly_content
invalid_section$section[[1]] <- "other"
expect_error(
  validate_weekly_content(invalid_section),
  "section must be lecture, workshop, practical, or extra",
  "Invalid sections should be rejected."
)

invalid_position <- weekly_content
invalid_position$position[[1]] <- 0
expect_error(
  validate_weekly_content(invalid_position),
  "positive whole numbers",
  "Invalid positions should be rejected."
)

blank_title <- weekly_content
blank_title$title[[1]] <- " "
expect_error(
  validate_weekly_content(blank_title),
  "must have a title",
  "Blank titles should be rejected."
)

duplicate_resource <- rbind(weekly_content, weekly_content[1, ])
expect_error(
  validate_weekly_content(duplicate_resource),
  "combination must be unique",
  "Duplicate positions should be rejected."
)

extra_practical <- weekly_content[
  weekly_content$week == 1 & weekly_content$section == "practical",
]
extra_practical$position <- 2
two_practicals <- rbind(weekly_content, extra_practical)
expect_error(
  validate_weekly_content(two_practicals),
  "at most one practical",
  "Multiple practicals in one week should be rejected."
)

missing_lecture <- weekly_content[
  !(weekly_content$week == 1 & weekly_content$section == "lecture"),
]
expect_error(
  validate_weekly_content(missing_lecture),
  "exactly one lecture theme",
  "Every week should require one lecture theme."
)

default_caption <- render_output("html", caption = NULL, include_caption = FALSE)
hidden_caption <- render_output("html", caption = FALSE)
custom_caption <- render_output("html", caption = "Custom schedule")
html_notes <- hidden_caption
expect_true(
  any(grepl("weekly-note-list", html_notes, fixed = TRUE)),
  "HTML Notes should use the semantic list wrapper."
)
expect_true(
  any(grepl(".bi-book", html_notes, fixed = TRUE)) &&
    any(grepl("Resource:", html_notes, fixed = TRUE)),
  "HTML Resources should include their decorative icon and visible label."
)
expect_true(
  any(grepl("Practice quiz (0%):", html_notes, fixed = TRUE)) &&
    any(grepl("Assessment (25%):", html_notes, fixed = TRUE)),
  "HTML quiz and Assessment labels should show their configured emphasis."
)
early_feedback_note <- html_notes[grepl(
  "Early Feedback Task",
  html_notes,
  fixed = TRUE
)]
expect_true(
  length(early_feedback_note) == 4L &&
    any(grepl("Assessment (5%):", early_feedback_note, fixed = TRUE)) &&
    any(grepl("Notice:", early_feedback_note, fixed = TRUE)) &&
    !any(grepl("Task \\(5\\%\\)", early_feedback_note, fixed = TRUE)),
  "The Early Feedback Task should distinguish its opening notice and deadline."
)
expect_true(
  any(grepl("[Notice:]{.weekly-note-category}", html_notes, fixed = TRUE)) &&
    !any(grepl("[Notice (", html_notes, fixed = TRUE)),
  "Notice labels should remain unweighted."
)
expect_true(
  any(grepl("weekly-note-external-marker", html_notes, fixed = TRUE)) &&
    any(grepl('aria-hidden="true"', html_notes, fixed = TRUE)),
  "External Notes should include one decorative external marker."
)

internal_note <- html_notes[grepl(
  "Am I ready for BEDA",
  html_notes,
  fixed = TRUE
)]
expect_true(
  length(internal_note) == 2 &&
    any(grepl("weekly-note-link", internal_note, fixed = TRUE)) &&
    !any(grepl("↗", internal_note, fixed = TRUE)),
  "Internal Notes should be linked without an external marker."
)

unlinked_note <- html_notes[grepl("Quiz 1", html_notes, fixed = TRUE)]
expect_true(
  length(unlinked_note) == 2 &&
    !any(grepl("[Quiz 1](", unlinked_note, fixed = TRUE)) &&
    !any(grepl("↗", unlinked_note, fixed = TRUE)),
  "Unlinked Notes should contain neither a link nor an external marker."
)

plain_notes <- render_output("plain", caption = FALSE)
expect_true(
  any(grepl(
    "(https://lindeloev.github.io/tests-as-linear/)",
    plain_notes,
    fixed = TRUE
  )),
  "Plain output should append an otherwise unavailable destination URL."
)

render_front_page <- function() {
  render_result <- suppressWarnings(system2(
    "quarto",
    c("render", "index.qmd"),
    stdout = TRUE,
    stderr = TRUE
  ))
  render_status <- attr(render_result, "status")
  if (is.null(render_status)) {
    render_status <- 0L
  }

  expect_true(
    render_status == 0L,
    paste("Quarto should render the front page.", paste(render_result, collapse = "\n"))
  )
  paste(
    readLines("_site/index.html", warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
}

rendered_html_table <- render_front_page()
expect_true(
  grepl(
    '<div id="weekly-content"[^>]*role="region"[^>]*aria-label="Weekly content schedule"',
    rendered_html_table,
    perl = TRUE
  ),
  "The schedule should retain its labelled responsive region."
)
expect_true(
  grepl(
    'scheduleTable.setAttribute("aria-label", "Weekly content schedule")',
    rendered_html_table,
    fixed = TRUE
  ) && grepl(
    'document.querySelector("#weekly-content table")',
    weekly_schedule_partial,
    fixed = TRUE
  ),
  "The rendered schedule should give its table a stable accessible name."
)
expect_true(
  grepl("weekly-schedule-desktop", rendered_html_table, fixed = TRUE) &&
    grepl("weekly-schedule-mobile", rendered_html_table, fixed = TRUE),
  "HTML should provide dedicated desktop and mobile schedule presentations."
)
expect_true(
  count_fixed_matches(rendered_html_table, 'data-schedule-week="') == 13L,
  "The mobile schedule should include one chronological block for every week."
)
expect_true(
  grepl(
    'class="weekly-current-week-jump" href="#mobile-week-1" hidden',
    rendered_html_table,
    fixed = TRUE
  ) &&
    grepl("Jump to current week", rendered_html_table, fixed = TRUE),
  "The mobile schedule should include a progressively enhanced current-week jump."
)
expect_true(
  grepl("weekly-mobile-break", rendered_html_table, fixed = TRUE) &&
    grepl(
      "<strong>Mid-semester break</strong> — 28 September–2 October 2026",
      rendered_html_table,
      fixed = TRUE
    ),
  "The chronological mobile schedule should include the configured semester break."
)
expect_true(
  grepl("Open Week 1 practical", rendered_html_table, fixed = TRUE) &&
    grepl("weekly-mobile-notes", rendered_html_table, fixed = TRUE),
  "Mobile weeks should keep practicals and Notes visible."
)
expect_true(
  grepl("@media (width < 48rem)", timeline_css, fixed = TRUE) &&
    grepl(
      "#weekly-content .weekly-schedule-desktop",
      timeline_css,
      fixed = TRUE
    ) &&
    grepl(".weekly-mobile-week.is-current-week", timeline_css, fixed = TRUE),
  "The schedule should switch presentations and retain current-week styling on phones."
)
expect_true(
  grepl(
    'document.querySelectorAll("#weekly-content .weekly-mobile-week")',
    semester_status_script,
    fixed = TRUE
  ) &&
    grepl(
      'jumpLink.href = `#mobile-week-${week}`',
      semester_status_script,
      fixed = TRUE
    ),
  "Current-week logic should update both the mobile highlight and jump target."
)
expect_true(
  !grepl("<caption", rendered_html_table, fixed = TRUE),
  "The accessible table name should not restore the visible caption."
)
expect_true(
  grepl(
    '<thead>[\\s\\S]*<th[^>]*>Week</th>[\\s\\S]*<th[^>]*>Notes</th>',
    rendered_html_table,
    perl = TRUE
  ),
  "The rendered schedule should retain programmatic column headers."
)
expect_true(
  grepl('class="[^"]*weekly-note-list', rendered_html_table, perl = TRUE) &&
    grepl("<ul>", rendered_html_table, fixed = TRUE) &&
    grepl("<li>", rendered_html_table, fixed = TRUE),
  "Rendered Notes should remain a semantic list."
)
expect_true(
  grepl(
    'class="[^"]*weekly-note-category[^"]*"[^>]*>Resource:',
    rendered_html_table,
    perl = TRUE
  ),
  "The category should be visible text rather than CSS-generated content."
)
expect_true(
  grepl(
    'class="[^"]*weekly-note-content[^"]*"',
    rendered_html_table,
    perl = TRUE
  ),
  "Each Note should group its category and destination beside the icon."
)
expect_true(
  !grepl('target="_blank"', rendered_html_table, fixed = TRUE),
  "Schedule links should remain in the same tab."
)
expect_true(
  !grepl("&lt;i class=", rendered_html_table, fixed = TRUE),
  "Decorative icons should not be escaped as visible code."
)
note_icon_tags <- regmatches(
  rendered_html_table,
  gregexpr(
    '<[^>]+class="[^"]*weekly-note-icon[^"]*"[^>]*>',
    rendered_html_table,
    perl = TRUE
  )
)[[1]]
note_icon_spans <- regmatches(
  rendered_html_table,
  gregexpr(
    '<span[^>]+class="[^"]*weekly-note-icon[^"]*"[^>]*>[^<]*</span>',
    rendered_html_table,
    perl = TRUE
  )
)[[1]]
external_marker_tags <- regmatches(
  rendered_html_table,
  gregexpr(
    '<span class="[^"]*weekly-note-external-marker[^"]*"[^>]*>',
    rendered_html_table,
    perl = TRUE
  )
)[[1]]
expect_true(
  length(note_icon_tags) ==
    2L * sum(
      weekly_content$section == "extra" & weekly_content$show_on_schedule
    ) &&
    all(grepl('aria-hidden="true"', note_icon_tags, fixed = TRUE)),
  "Every rendered Note icon should be decorative."
)
expect_true(
  length(note_icon_spans) == length(note_icon_tags) &&
    all(grepl(">\\s*</span>$", note_icon_spans, perl = TRUE)),
  paste0(
    "Decorative Note icon spans should be empty so hidden text cannot ",
    "distort their baseline."
  )
)
expect_true(
  length(external_marker_tags) > 0L &&
    all(grepl('aria-hidden="true"', external_marker_tags, fixed = TRUE)),
  "Every rendered external marker should be decorative."
)
expect_true(
  !grepl('&lt;i class="bi bi-flask"', rendered_html_table, fixed = TRUE),
  "Linked practical icons should not appear as escaped HTML in the rendered table."
)
expect_true(
  grepl(
    paste0(
      '<a href="./module01/102-week01.html"[^>]*>',
      'Week 1 practical session</a>'
    ),
    rendered_html_table,
    perl = TRUE
  ) || grepl(
    "<td>Week 1 practical session</td>",
    rendered_html_table,
    fixed = TRUE
  ),
  "Rendered practical cells should retain their accessible text when draft links are removed."
)
expect_true(
  grepl(
    paste0(
      "#weekly-content tbody tr:not(:has(.semester-break-row)) ",
      "td:nth-child(3):not(:has(> a))",
      ":not(:has(> .weekly-practical-link))"
    ),
    timeline_css,
    fixed = TRUE
  ),
  "Draft practical cells should retain the flask icon after Quarto removes their links."
)

expect_true(
  any(default_caption == "BEDA weekly content"),
  "The default caption should be retained."
)
expect_true(
  !any(grepl("BEDA weekly content", hidden_caption, fixed = TRUE)),
  "caption = FALSE should suppress the caption."
)
expect_true(
  any(custom_caption == "Custom schedule"),
  "A custom caption should be rendered."
)
expect_true(
  sum(grepl("^- - [0-9]+$", hidden_caption)) == 13,
  "The table output should contain 13 weekly rows."
)
break_row <- which(hidden_caption == "- - [Break]{.semester-break-row}")
week_eight_row <- which(hidden_caption == "- - 8")
week_nine_row <- which(hidden_caption == "- - 9")
expect_true(
  length(break_row) == 1 &&
    week_eight_row < break_row &&
    break_row < week_nine_row,
  "The mid-semester break should appear between Weeks 8 and 9."
)
expect_true(
  any(hidden_caption == paste0(
    "  - **Mid\\-semester break** — ",
    "28 September–2 October 2026"
  )) &&
    sum(hidden_caption[break_row:(week_nine_row - 1)] == "  -") == 2,
  "The break row should show its dates beside the title and leave other cells blank."
)
expect_true(
  any(grepl(week_one_escaped_description, hidden_caption, fixed = TRUE)),
  "HTML table output should include lecture descriptions."
)
expect_true(
  sum(grepl("weekly-lecture-description", hidden_caption, fixed = TRUE)) == 13,
  "HTML table output should contain 13 lecture description lines."
)
expect_true(
  grepl(".weekly-practical-link::before", timeline_css, fixed = TRUE) &&
    grepl("mask: url(\"data:image/svg+xml", timeline_css, fixed = TRUE) &&
    !grepl('content: "\\f90a";', timeline_css, fixed = TRUE),
  "The practical link should use a decorative CSS flask mask."
)
expect_true(
  any(hidden_caption == "  - Practical"),
  "The schedule should use the concise Practical heading."
)
expect_true(
  any(hidden_caption == "  - Notes"),
  "The schedule should label the final column Notes."
)
expect_true(
  grepl("#weekly-content td:nth-child(4)", timeline_css, fixed = TRUE) &&
    grepl("font-size: 0.9em;", timeline_css, fixed = TRUE) &&
    grepl("line-height: 1.35;", timeline_css, fixed = TRUE),
  "Notes should use the lecture-description type scale."
)
required_note_css <- c(
  ".weekly-note-list",
  "list-style: none",
  ".weekly-note-icon",
  "color: #0f6b5b",
  ".weekly-note-category",
  ".weekly-note-link",
  "text-decoration: underline",
  ".weekly-note-link:focus-visible",
  "outline: 3px solid",
  "#weekly-content",
  "overflow-x: auto"
)
for (rule in required_note_css) {
  expect_true(
    grepl(rule, timeline_css, fixed = TRUE),
    paste("Schedule CSS should contain:", rule)
  )
}
expect_true(
  grepl(
    ".weekly-note-category {\n  color: #5c636a;",
    timeline_css,
    fixed = TRUE
  ),
  "Notes categories should use an explicit accessible secondary colour."
)
hex_luminance <- function(value) {
  channels <- strtoi(
    substring(value, c(2, 4, 6), c(3, 5, 7)),
    base = 16L
  ) / 255
  channels <- ifelse(
    channels <= 0.04045,
    channels / 12.92,
    ((channels + 0.055) / 1.055)^2.4
  )
  sum(channels * c(0.2126, 0.7152, 0.0722))
}
category_contrast <- (hex_luminance("#ffffff") + 0.05) /
  (hex_luminance("#5c636a") + 0.05)
expect_true(
  category_contrast >= 4.5,
  "The explicit Notes category colour should meet 4.5:1 on white."
)
expect_true(
  grepl(
    "#weekly-content .weekly-note-list .weekly-note-link",
    timeline_css,
    fixed = TRUE
  ),
  "Semantic Notes link selectors should override generic table-link rules."
)
expect_true(
  grepl("fontsize: 16px", quarto_config, fixed = TRUE),
  "The site should retain a 16 px accessible base font size."
)
expect_true(
  grepl("collapse-below: lg", quarto_config, fixed = TRUE),
  "Navigation should collapse before its links or brand become cramped."
)
expect_true(
  grepl(
    "@media (min-width: 992px) and (max-width: 1199.98px)",
    timeline_css,
    fixed = TRUE
  ) && grepl(
    ".navbar.navbar-expand-xl #quarto-search",
    timeline_css,
    fixed = TRUE
  ),
  "Search ordering should stay in mobile mode until the XL navbar expands."
)
expect_true(
  grepl(".navbar {", timeline_css, fixed = TRUE) &&
    grepl("font-size: 1rem;", timeline_css, fixed = TRUE),
  "Navigation should use the full base font size."
)
expect_true(
  grepl("background-color: #0f6b5b !important;", timeline_css, fixed = TRUE) &&
    grepl("--bs-navbar-color: #fff;", timeline_css, fixed = TRUE),
  "Navigation should use the accessible dark-green palette."
)
expect_true(
  grepl("outline: 3px solid #fde725;", timeline_css, fixed = TRUE),
  "Navigation focus should remain visible against the dark-green background."
)
expect_true(
  grepl("#semester-status {", timeline_css, fixed = TRUE) &&
    grepl("text-align: center;", timeline_css, fixed = TRUE) &&
    grepl("font-weight: 700;", timeline_css, fixed = TRUE) &&
    grepl("color: #0f6b5b;", timeline_css, fixed = TRUE),
  "The dynamic semester status should be centred, bold and navigation green."
)
expect_true(
  grepl("tr.is-current-week > *", timeline_css, fixed = TRUE) &&
    grepl(".current-week-label", timeline_css, fixed = TRUE),
  "The current week should have both row styling and a visible text marker."
)
expect_true(
  grepl(
    'highlightScheduleWeek(1, "Coming up", false);',
    semester_status_script,
    fixed = TRUE
  ) &&
    grepl("DOMContentLoaded", semester_status_script, fixed = TRUE) &&
    grepl('aria-current", "true', semester_status_script, fixed = TRUE),
  paste(
    "The semester script should mark Week 1 as coming up before semester",
    "and wait for the table DOM."
  )
)
expect_true(
  grepl("#weekly-content table {\n  font-size: 1rem;", timeline_css, fixed = TRUE),
  "The weekly table should use the full base font size."
)
expect_true(
  grepl("color: #005ea8;", timeline_css, fixed = TRUE) &&
    grepl("color: #003f73;", timeline_css, fixed = TRUE),
  "Schedule links should use the accessible blue palette."
)
expect_true(
  !any(grepl(
    "[Software and graphical models](",
    hidden_caption,
    fixed = TRUE
  )),
  "A hidden workshop should not appear as a separate visible schedule link."
)
expected_visible_rows <- weekly_content[
  weekly_content$show_on_schedule,
  c("section", "title"),
  drop = FALSE
]
expect_true(
  all(vapply(
    seq_len(nrow(expected_visible_rows)),
    function(index) {
      title <- expected_visible_rows$title[[index]]
      escaped_title <- if (expected_visible_rows$section[[index]] == "extra") {
        escape_markdown_text(title)
      } else {
        escape_markdown_label(title)
      }
      any(grepl(escaped_title, hidden_caption, fixed = TRUE))
    },
    logical(1)
  )),
  "Every intended TRUE row should remain present in the schedule output."
)
expect_true(
  any(grepl(
    '[Week 1 practical session](module01/102-week01.qmd "Getting started")',
    hidden_caption,
    fixed = TRUE
  )),
  "The Week 1 practical icon should describe the combined Week 1 session."
)
expect_true(
  any(grepl(
    "[Week 1 practical session](module01/102-week01.qmd",
    hidden_caption,
    fixed = TRUE
  )),
  "The Week 1 practical-session icon should open the combined Week 1 page."
)
expect_true(
  any(grepl(
    'aria-label="Week 2 practical session"',
    hidden_caption,
    fixed = TRUE
  )) &&
    !any(grepl("module01/103-week02.qmd", hidden_caption, fixed = TRUE)),
  "Week 2 practical should remain visible without a schedule link."
)
expect_true(
  any(grepl(
    'aria-label="Week 3 practical session"',
    hidden_caption,
    fixed = TRUE
  )) &&
    !any(grepl("module01/104-week03.qmd", hidden_caption, fixed = TRUE)),
  "Week 3 practical should remain visible without a schedule link."
)

latex_output <- render_output("latex", caption = FALSE)
expect_true(
  any(grepl(week_one_escaped_description, latex_output, fixed = TRUE)),
  "LaTeX output should include lecture descriptions."
)
expect_true(
  !any(grepl("<span", latex_output, fixed = TRUE)),
  "LaTeX output should not contain raw span elements."
)
expect_true(
  !any(grepl("bi-flask", latex_output, fixed = TRUE)),
  "Non-HTML output should not contain HTML practical icons."
)
expect_true(
  any(latex_output == "- - [Break]{.semester-break-row}"),
  "LaTeX table output should include the semester break row."
)
expect_true(
  any(grepl("[Practical session](", latex_output, fixed = TRUE)),
  "Non-HTML practicals should use Markdown links."
)

typst_external_link <- run_pandoc(
  "typst",
  weekly_note_markdown(entries[[2]]$extras[[1]], html_output = FALSE)
)
expect_true(
  any(grepl(
    '#link("https://lindeloev.github.io/tests-as-linear/")[',
    typst_external_link,
    fixed = TRUE
  )),
  "Pandoc Typst output should retain a functional external Notes link."
)

typst_output <- render_output("typst", caption = FALSE)
expect_true(
  any(typst_output == "**Notes**"),
  "Typst should call the section Notes."
)
expect_true(
  any(grepl("**Resource:**", typst_output, fixed = TRUE)),
  "Typst should preserve visible category labels."
)
expect_true(
  any(grepl("**Practice quiz (0%):** Quiz 1", typst_output, fixed = TRUE)) &&
    any(grepl(
      paste0(
        "**Assessment (15%):** Report 2 individual report due ",
        "Friday 6 November at 23\\:59"
      ),
      typst_output,
      fixed = TRUE
    )),
  "Typst should distinguish practice quizzes from weighted Assessments."
)
expect_true(
  any(grepl("**Notice:**", typst_output, fixed = TRUE)) &&
    !any(grepl("**Notice (", typst_output, fixed = TRUE)),
  "Typst Notice labels should remain unweighted."
)
expect_true(
  any(grepl(
    paste0(
      "[Common statistical tests are linear models]",
      "(<https://lindeloev.github.io/tests-as-linear/>)"
    ),
    typst_output,
    fixed = TRUE
  )),
  "Typst should preserve the external hyperlink."
)
expect_true(
  any(grepl(week_one_escaped_description, typst_output, fixed = TRUE)),
  "Typst output should include lecture descriptions."
)
expect_true(
  !any(grepl("<span", typst_output, fixed = TRUE)),
  "Typst output should not contain raw span elements."
)
expect_true(
  any(typst_output == "## Weekly schedule"),
  "Typst output should use the compact weekly schedule."
)
expect_true(
  any(typst_output == "### Mid\\-semester break") &&
    any(typst_output == "28 September–2 October 2026") &&
    !any(typst_output == "No classes"),
  "Typst output should include the semester break and its dates."
)
expect_true(
  !any(grepl("list-table", typst_output, fixed = TRUE)),
  "Typst output should not use the wide list table."
)

cat("PASS: weekly content renderer (", checks, " checks)\n", sep = "")
