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
  any(grepl("bi-flask", hidden_caption, fixed = TRUE)),
  "HTML output should contain practical icons."
)

latex_output <- render_output("latex", caption = FALSE)
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
  any(typst_output == "## Weekly schedule"),
  "Typst output should use the compact weekly schedule."
)
expect_true(
  !any(grepl("list-table", typst_output, fixed = TRUE)),
  "Typst output should not use the wide list table."
)

cat("PASS: weekly content renderer (", checks, " checks)\n", sep = "")
