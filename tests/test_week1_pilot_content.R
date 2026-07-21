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
  unname(tools::md5sum(dataset_path)) == "ae91b3957d5cb695441bf9404b456fd3",
  "The canonical dataset should match the checked-in palmerpenguins 0.1.1 export."
)

penguins <- read.csv(
  dataset_path,
  stringsAsFactors = FALSE,
  na.strings = "",
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
workshop <- read_text("module01/w01-intro.qmd")
practical <- read_text("module01/102-week01.qmd")

timed_labels <- unlist(regmatches(
  workshop,
  gregexpr(
    "(?m)^### [1-6]\\..*— ([0-9]+) minutes(?: \\{[^\\n]+\\})?$",
    workshop,
    perl = TRUE
  )
))
timed_minutes <- as.integer(sub(
  ".*— ([0-9]+) minutes(?: \\{[^\\n]+\\})?$",
  "\\1",
  timed_labels,
  perl = TRUE
))
expect_true(
  length(timed_minutes) == 6L && sum(timed_minutes) == 40L,
  "Workshop 1 should contain six timed activities totalling 40 minutes."
)
expect_true(
  grepl("5 minutes of flex time", workshop, fixed = TRUE),
  "Workshop 1 should protect five minutes of flex time."
)

route_labels <- c(
  "Jamovi — recommended",
  "R/RStudio — for students with prior R experience",
  "SPSS — supported alternative"
)
route_positions <- vapply(
  route_labels,
  function(label) regexpr(label, workshop, fixed = TRUE)[[1]],
  integer(1)
)
expect_true(
  all(route_positions > 0L) && identical(order(route_positions), 1:3),
  "Workshop 1 should present Jamovi, experienced R, then SPSS."
)
expect_true(
  grepl("Complete one software route only", workshop, fixed = TRUE),
  "Students should be told to complete one software route only."
)
expect_true(
  grepl("assets/penguins.csv", workshop, fixed = TRUE),
  "Workshop 1 should link to the local penguin CSV."
)
for (anchor in c(
  "../cheatsheets.qmd#cheatsheet-jamovi-boxplot",
  "../cheatsheets.qmd#cheatsheet-r-boxplot",
  "../cheatsheets.qmd#cheatsheet-spss-boxplot"
)) {
  expect_true(
    grepl(anchor, workshop, fixed = TRUE),
    paste("Workshop 1 should link through the stable local anchor", anchor)
  )
}
expect_true(
  match_count("**Do this**", workshop) >= 6L &&
    match_count("**Expected result**", workshop) >= 6L &&
    match_count("**If this did not happen**", workshop) >= 6L,
  "Every major workshop activity should state the action, result, and recovery."
)
expect_true(
  grepl("Conceptual readiness — required", workshop, fixed = TRUE) &&
    grepl("Software readiness — complete or follow-up required", workshop, fixed = TRUE),
  "Workshop 1 should separate conceptual and software readiness."
)
expect_true(
  grepl("supplied plot used; software follow-up recorded", workshop, fixed = TRUE),
  "The Model Card should support the no-software fallback truthfully."
)
expect_true(
  grepl("species ~ island", workshop, fixed = TRUE),
  "Workshop 1 should include the approved invalid variable pairing."
)
reference_position <- regexpr(
  "## Software reference — not part of today's workshop",
  workshop,
  fixed = TRUE
)[[1]]
readiness_position <- regexpr("#readiness-checkpoints}", workshop, fixed = TRUE)[[1]]
expect_true(
  reference_position > readiness_position && readiness_position > 0L,
  "Broad software reference material should follow the timed workshop and readiness checks."
)

expect_true(
  !grepl("## Workshop 01", practical, fixed = TRUE) &&
    !grepl("## Exercise 1 – Cheatsheets", practical, fixed = TRUE),
  "Practical 1 should not duplicate the workshop or cheatsheet exercise."
)
expect_true(
  grepl("[penguins.csv](assets/penguins.csv)", practical, fixed = TRUE) &&
    !grepl("44247073", practical, fixed = TRUE),
  "Practical 1 should use the canonical local penguin download."
)
expect_true(
  !grepl("histogram", practical, ignore.case = TRUE),
  "Practical 1 should not retain the univariate histogram option."
)
expect_true(
  grepl("## Example", practical, fixed = TRUE) &&
    grepl("#fancy-a-challenge}", practical, fixed = TRUE) &&
    grepl("possums.xlsx", practical, fixed = TRUE),
  "Practical 1 should retain its worked possum example and challenge."
)
expect_true(
  !grepl("#### What is a model?", practical, fixed = TRUE),
  "Practical 1 should use a concise recap rather than repeat the lecture explanation."
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
