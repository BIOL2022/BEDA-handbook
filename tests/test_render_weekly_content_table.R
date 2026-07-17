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

weekly_content <- read.csv(
  "data/weekly_content.csv",
  stringsAsFactors = FALSE,
  check.names = FALSE
)
week_one_description <- weekly_content$description[
  weekly_content$week == 1 & weekly_content$section == "lecture"
][[1]]
week_one_escaped_description <- escape_markdown_text(week_one_description)

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

render_output <- function(pandoc_to, caption, include_caption = TRUE) {
  previous_output <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  on.exit(
    knitr::opts_knit$set(rmarkdown.pandoc.to = previous_output),
    add = TRUE
  )
  knitr::opts_knit$set(rmarkdown.pandoc.to = pandoc_to)

  arguments <- list(weekly_content = weekly_content)
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

entries <- weekly_content_entries(weekly_content)
expect_true(length(entries) == 13, "The renderer should create 13 weeks.")
expect_true(
  identical(vapply(entries, `[[`, integer(1), "week"), 1:13),
  "Weeks should be ordered from 1 to 13."
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
  "section must be lecture, practical, or extra",
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
expect_true(
  any(grepl(week_one_escaped_description, hidden_caption, fixed = TRUE)),
  "HTML table output should include lecture descriptions."
)
expect_true(
  sum(grepl("weekly-lecture-description", hidden_caption, fixed = TRUE)) == 13,
  "HTML table output should contain 13 lecture description lines."
)
expect_true(
  any(grepl("bi-flask", hidden_caption, fixed = TRUE)),
  "HTML output should contain practical icons."
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
  any(grepl("[Practical](", latex_output, fixed = TRUE)),
  "Non-HTML practicals should use Markdown links."
)

typst_output <- render_output("typst", caption = FALSE)
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
  !any(grepl("list-table", typst_output, fixed = TRUE)),
  "Typst output should not use the wide list table."
)

cat("PASS: weekly content renderer (", checks, " checks)\n", sep = "")
