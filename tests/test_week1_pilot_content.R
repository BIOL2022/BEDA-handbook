#!/usr/bin/env Rscript

script_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
script_file <- normalizePath(sub("^--file=", "", script_argument[[1]]))
repo_root <- normalizePath(file.path(dirname(script_file), ".."))
setwd(repo_root)

checks <- 0L

expect_true <- function(condition, message) {
  checks <<- checks + 1L
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

match_count <- function(pattern, text, fixed = TRUE) {
  matches <- gregexpr(pattern, text, fixed = fixed)[[1]]
  if (identical(matches, -1L)) 0L else length(matches)
}

dataset_path <- "module01/assets/penguins.csv"
expect_true(file.exists(dataset_path), "The canonical penguin CSV should exist.")
expect_true(
  unname(tools::md5sum(dataset_path)) == "a06a0210251465a86fb970018292304d",
  "The canonical dataset should match the official palmerpenguins 0.1.1 CSV."
)

penguins <- read.csv(
  dataset_path,
  stringsAsFactors = FALSE,
  na.strings = "NA",
  check.names = FALSE
)
expected_columns <- c(
  "species", "island", "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g", "sex", "year"
)
expect_true(nrow(penguins) == 344L, "The canonical dataset should have 344 rows.")
expect_true(
  identical(names(penguins), expected_columns),
  "The canonical dataset should have the eight specified columns in order."
)
expect_true(
  sum(is.na(penguins)) == 19L,
  "The canonical dataset should have 19 empty data cells."
)

if (
  requireNamespace("palmerpenguins", quietly = TRUE) &&
    as.character(utils::packageVersion("palmerpenguins")) == "0.1.1"
) {
  source_penguins <- as.data.frame(palmerpenguins::penguins)
  source_penguins[] <- lapply(source_penguins, function(column) {
    if (is.factor(column)) as.character(column) else column
  })
  expect_true(
    isTRUE(all.equal(penguins, source_penguins, check.attributes = FALSE)),
    "The local CSV should be an unchanged export of palmerpenguins::penguins."
  )
}

cheatsheets <- read_text("cheatsheets.qmd")
for (anchor in c(
  "#cheatsheet-jamovi-boxplot",
  "#cheatsheet-r-boxplot",
  "#cheatsheet-spss-boxplot"
)) {
  expect_true(
    match_count(anchor, cheatsheets) == 1L,
    paste("The cheatsheets page should define exactly one", anchor, "anchor.")
  )
}

lecture <- read_text("lectures/L01/index.qmd")
week1 <- read_text("module01/102-week01.qmd")

workshop <- sub(
  "^[\\s\\S]*?(## Workshop[\\s\\S]*?)\\n## Practical[\\s\\S]*$",
  "\\1",
  week1,
  perl = TRUE
)
practical <- sub(
  "^[\\s\\S]*?(## Practical[\\s\\S]*)$",
  "\\1",
  week1,
  perl = TRUE
)

expect_true(
  grepl("## Workshop", week1, fixed = TRUE) &&
    grepl("## Practical", week1, fixed = TRUE),
  "Week 1 should combine the Workshop and Practical as level-two sections."
)

expect_true(
  grepl("### Pick your software (15 min)", workshop, fixed = TRUE) &&
    grepl("### A simple modelling exercise (10 min)", workshop, fixed = TRUE) &&
    grepl("### Introduction to cheatsheets (5 min)", workshop, fixed = TRUE),
  "The Workshop should retain its three introductory activities."
)

route_labels <- c(
  "#### Jamovi",
  "#### R/RStudio",
  "#### R/Positron"
)
route_positions <- vapply(
  route_labels,
  function(label) regexpr(label, workshop, fixed = TRUE)[[1]],
  integer(1)
)
expect_true(
  all(route_positions > 0L) && identical(order(route_positions), 1:3),
  "The Workshop should present Jamovi, RStudio, then Positron."
)
expect_true(
  match_count("::: {.panel-tabset}", workshop) == 1L,
  "The software choices should appear in one tabset."
)
expect_true(
  grepl("assets/penguins.png", workshop, fixed = TRUE) &&
    grepl("assets/culmen_depth.png", workshop, fixed = TRUE),
  "The Workshop should use the two penguin teaching illustrations."
)
expect_true(
  grepl(
    "courses/74353/files/51697284/download?download_frd=1",
    week1,
    fixed = TRUE
  ) &&
    grepl(
      "courses/74353/files/51697285/download?download_frd=1",
      week1,
      fixed = TRUE
    ) &&
    !grepl("44247073", practical, fixed = TRUE),
  "Week 1 should use the canonical Canvas-hosted dataset downloads."
)
expect_true(
  match_count("{.student-task}", practical) == 3L &&
    all(vapply(
      paste("Task", 1:3),
      function(label) grepl(label, practical, fixed = TRUE),
      logical(1)
    )),
  "Each practical exercise should contain a clear numbered Task heading."
)
expect_true(
  grepl("### Exercise: Cheatsheets", practical, fixed = TRUE) &&
    grepl("### Exercise: Data types", practical, fixed = TRUE) &&
    grepl("### Exercise: Modelling basics", practical, fixed = TRUE),
  "The Practical should retain all three exercises."
)
expect_true(
  grepl("fig-dog-sleep-age-groups", practical, fixed = TRUE) &&
    grepl("fig-dog-sleep-age-continuous", practical, fixed = TRUE),
  "Exercise 3 should retain both accessible dog-sleep examples."
)
expect_true(
  grepl("Complete all five steps below", practical, fixed = TRUE) &&
    grepl("Your lab notebook should contain:", practical, fixed = TRUE),
  "Exercise 3 should state the complete task and required notebook contents."
)
expect_true(
  grepl("### That is a wrap", practical, fixed = TRUE) &&
    grepl("10-minute Q&A session", practical, fixed = TRUE),
  "The Practical should finish with the closing Q&A and attendance reminder."
)

expect_true(
  match_count('::: {.content-visible when-format="html"}', lecture) == 2L,
  "Both lecture previews should be explicitly HTML-only."
)
expect_true(
  match_count("bi-arrows-fullscreen", lecture) == 2L &&
    match_count("bi-file-earmark-pdf", lecture) == 2L,
  "The lecture hub should retain both descriptive actions for both lectures."
)

cat("PASS: Week 1 pilot content (", checks, " checks)\n", sep = "")
