#!/usr/bin/env Rscript

script_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
script_file <- normalizePath(sub("^--file=", "", script_argument[[1]]))
repo_root <- normalizePath(file.path(dirname(script_file), ".."))

checks <- 0L

expect_true <- function(condition, message) {
  checks <<- checks + 1L
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

match_count <- function(pattern, text) {
  matches <- gregexpr(pattern, text, fixed = TRUE)[[1]]
  if (identical(matches, -1L)) 0L else length(matches)
}

fixture_root <- tempfile("week1-latex-render-")
dir.create(file.path(fixture_root, "lectures", "L01"), recursive = TRUE)
dir.create(file.path(fixture_root, "assets"), recursive = TRUE)
on.exit(unlink(fixture_root, recursive = TRUE), add = TRUE)

files_to_copy <- c(
  "lectures/L01/index.qmd",
  "_quarto.yml",
  "assets/timeline.css"
)
for (source in files_to_copy) {
  expect_true(
    file.copy(
      file.path(repo_root, source),
      file.path(fixture_root, source),
      overwrite = TRUE
    ),
    paste("The render fixture should copy", source)
  )
}

previous_directory <- getwd()
on.exit(setwd(previous_directory), add = TRUE)
setwd(fixture_root)

render_output <- suppressWarnings(system2(
  "quarto",
  c("render", "lectures/L01/index.qmd", "--to", "latex"),
  stdout = TRUE,
  stderr = TRUE
))
render_status <- attr(render_output, "status")
if (is.null(render_status)) {
  render_status <- 0L
}
expect_true(
  render_status == 0L,
  paste("The Week 1 lecture should render to LaTeX.", paste(render_output, collapse = "\n"))
)

tex_files <- list.files(
  fixture_root,
  pattern = "index\\.tex$",
  recursive = TRUE,
  full.names = TRUE
)
expect_true(length(tex_files) == 1L, "The LaTeX render should create one index.tex file.")

latex <- paste(readLines(tex_files[[1]], warn = FALSE), collapse = "\n")
latex_flat <- gsub("[[:space:]]+", " ", latex)
expect_true(
  !grepl("<iframe", latex, fixed = TRUE),
  "The LaTeX lecture should omit raw HTML iframe previews."
)
expect_true(
  match_count("Full screen", latex_flat) == 2L,
  "The LaTeX lecture should retain both descriptive full-screen links."
)
expect_true(
  lengths(regmatches(
    latex_flat,
    gregexpr(
      "\\\\href\\{[^}]+\\.pdf\\}\\{ *PDF\\}",
      latex_flat,
      perl = TRUE
    )
  )) == 2L,
  "The LaTeX lecture should retain both descriptive PDF links."
)
cat(sprintf("PASS: non-HTML lecture render (%d checks)\n", checks))
