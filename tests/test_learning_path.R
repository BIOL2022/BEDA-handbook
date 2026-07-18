#!/usr/bin/env Rscript

script_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
script_file <- normalizePath(sub("^--file=", "", script_argument[[1]]))
repo_root <- normalizePath(file.path(dirname(script_file), ".."))
filter_path <- file.path(repo_root, "filters", "learning-path.lua")

checks <- 0L

expect_true <- function(condition, message) {
  checks <<- checks + 1L
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

fixture_root <- tempfile("week-learning-path-")
dir.create(file.path(fixture_root, "lectures", "L01"), recursive = TRUE)
dir.create(file.path(fixture_root, "module01"), recursive = TRUE)
on.exit(unlink(fixture_root, recursive = TRUE), add = TRUE)

input_files <- c(
  "lectures/L01/index.qmd",
  "module01/w01-intro.qmd",
  "module01/102-week01.qmd",
  "other.qmd"
)
input_text <- c(
  "---",
  "learning-path-data: weekly.csv",
  "learning-path-root: .",
  "---",
  "",
  "::: {.week-learning-path week=\"1\"}",
  ":::"
)
for (input_file in input_files) {
  writeLines(input_text, file.path(fixture_root, input_file), useBytes = TRUE)
}

valid_csv <- c(
  "week,section,position,title,url,description,show_on_schedule",
  '1,lecture,1,"Intro, fundamentals",lectures/L01/index.qmd,"Theme, one",TRUE',
  "1,workshop,1,Software and graphical models,module01/w01-intro.qmd,,FALSE",
  "1,practical,1,Getting started,module01/102-week01.qmd,,TRUE"
)

write_fixture_csv <- function(lines) {
  connection <- file(file.path(fixture_root, "weekly.csv"), open = "wb")
  on.exit(close(connection), add = TRUE)
  writeChar(
    paste(lines, collapse = "\r\n"),
    connection,
    eos = NULL,
    useBytes = TRUE
  )
}

run_filter <- function(input_file, to = "html") {
  previous_directory <- getwd()
  on.exit(setwd(previous_directory), add = TRUE)
  setwd(fixture_root)

  output <- suppressWarnings(system2(
    "quarto",
    c(
      "pandoc",
      input_file,
      paste0("--lua-filter=", shQuote(filter_path)),
      paste0("--to=", to),
      "--wrap=none"
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  list(status = status, output = paste(output, collapse = "\n"))
}

expect_failure <- function(csv, input_file, pattern, message) {
  write_fixture_csv(csv)
  result <- run_filter(input_file)
  expect_true(result$status != 0L, message)
  expect_true(
    grepl(pattern, result$output, fixed = TRUE),
    paste(message, "Unexpected output:", result$output)
  )
}

expect_true(file.exists(filter_path), "The shared learning-path filter should exist.")

write_fixture_csv(valid_csv)
lecture_html <- run_filter("lectures/L01/index.qmd")
expect_true(
  lecture_html$status == 0L,
  paste("The valid lecture pathway should render.", lecture_html$output)
)
expect_true(
  grepl('<h2 id="week-1-learning-path">Week 1 learning path</h2>', lecture_html$output, fixed = TRUE),
  "The pathway should have its visible Week 1 heading."
)
expect_true(
  lengths(regmatches(lecture_html$output, gregexpr("<li>", lecture_html$output, fixed = TRUE))) == 3L,
  "The pathway should contain exactly three ordered items."
)
expect_true(
  lengths(regmatches(lecture_html$output, gregexpr("<a href=", lecture_html$output, fixed = TRUE))) == 2L,
  "Only the two non-current pathway items should be links."
)
expect_true(
  grepl("Lectures — learn the ideas: Intro, fundamentals — you are here", lecture_html$output, fixed = TRUE),
  "The current lecture should be non-linked text with the current-page suffix."
)
expected_labels <- c(
  "Lectures — learn the ideas: Intro, fundamentals",
  "Workshop — practise the fundamentals: Software and graphical models",
  "Practical — apply them: Getting started"
)
label_positions <- vapply(
  expected_labels,
  function(label) regexpr(label, lecture_html$output, fixed = TRUE)[[1]],
  integer(1)
)
expect_true(
  all(label_positions > 0L) && identical(order(label_positions), 1:3),
  "The pathway items should remain in lecture, workshop, practical order."
)

write_fixture_csv(valid_csv)
native_output <- run_filter("module01/w01-intro.qmd", to = "native")
expect_true(
  native_output$status == 0L,
  paste(
    "The valid workshop pathway should render to native AST.",
    native_output$output
  )
)
expect_true(
  grepl("OrderedList", native_output$output, fixed = TRUE),
  "The pathway should be a Pandoc ordered list."
)
expect_true(
  !grepl("RawBlock", native_output$output, fixed = TRUE),
  "The pathway should not depend on a raw HTML block."
)

expect_failure(
  valid_csv[valid_csv != valid_csv[[3]]],
  "lectures/L01/index.qmd",
  "Week 1 learning path requires exactly one workshop row.",
  "A missing workshop row should fail clearly."
)

expect_failure(
  c(valid_csv, "1,workshop,2,Second workshop,module01/other-workshop.qmd,,FALSE"),
  "lectures/L01/index.qmd",
  "Week 1 learning path requires exactly one workshop row.",
  "Multiple workshop rows should fail clearly."
)

duplicate_url_csv <- valid_csv
duplicate_url_csv[[4]] <- "1,practical,1,Getting started,module01/w01-intro.qmd,,TRUE"
expect_failure(
  duplicate_url_csv,
  "lectures/L01/index.qmd",
  "Week 1 learning path URLs must be present and unique.",
  "Duplicate pathway URLs should fail clearly."
)

equivalent_duplicate_url_csv <- valid_csv
equivalent_duplicate_url_csv[[4]] <-
  "1,practical,1,Getting started,./module01/w01-intro.qmd,,TRUE"
expect_failure(
  equivalent_duplicate_url_csv,
  "lectures/L01/index.qmd",
  "Week 1 learning path URLs must be present and unique.",
  "Equivalent pathway URLs should fail after path normalization."
)

parent_alias_duplicate_url_csv <- valid_csv
parent_alias_duplicate_url_csv[[4]] <-
  "1,practical,1,Getting started,module01/../module01/w01-intro.qmd,,TRUE"
expect_failure(
  parent_alias_duplicate_url_csv,
  "lectures/L01/index.qmd",
  "Week 1 learning path URLs must be present and unique.",
  "Parent-directory aliases should fail after path normalization."
)

missing_url_csv <- valid_csv
missing_url_csv[[4]] <- "1,practical,1,Getting started,,,TRUE"
expect_failure(
  missing_url_csv,
  "lectures/L01/index.qmd",
  "Week 1 learning path URLs must be present and unique.",
  "Missing pathway URLs should fail clearly."
)

expect_failure(
  valid_csv,
  "other.qmd",
  "Current page 'other.qmd' does not match exactly one Week 1 learning-path URL.",
  "A page outside the pathway should fail clearly when it contains the marker."
)

run_production_filter <- function(input_file) {
  previous_directory <- getwd()
  on.exit(setwd(previous_directory), add = TRUE)
  setwd(repo_root)

  output <- suppressWarnings(system2(
    "quarto",
    c(
      "pandoc",
      input_file,
      paste0("--lua-filter=", shQuote(filter_path)),
      "--to=html",
      "--wrap=none"
    ),
    env = paste0("QUARTO_PROJECT_DIR=", shQuote(repo_root)),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }
  list(status = status, output = paste(output, collapse = "\n"))
}

production_cases <- list(
  list(
    file = "lectures/L01/index.qmd",
    current = "Lectures — learn the ideas: Introduction and fundamentals — you are here",
    links = c("../../module01/w01-intro.qmd", "../../module01/102-week01.qmd")
  ),
  list(
    file = "module01/w01-intro.qmd",
    current = "Workshop — practise the fundamentals: Software and graphical models — you are here",
    links = c("../lectures/L01/index.qmd", "102-week01.qmd")
  ),
  list(
    file = "module01/102-week01.qmd",
    current = "Practical — apply them: Getting started — you are here",
    links = c("../lectures/L01/index.qmd", "w01-intro.qmd")
  )
)

for (case in production_cases) {
  result <- run_production_filter(case$file)
  expect_true(
    result$status == 0L,
    paste("The maintained pathway should render for", case$file, result$output)
  )
  expect_true(
    grepl(case$current, result$output, fixed = TRUE),
    paste("The maintained pathway should identify the current page for", case$file)
  )
  for (link in case$links) {
    expect_true(
      grepl(paste0('href="', link, '"'), result$output, fixed = TRUE),
      paste("The maintained pathway should resolve", link, "from", case$file)
    )
  }
}

cat("PASS: learning-path filter (", checks, " checks)\n", sep = "")
