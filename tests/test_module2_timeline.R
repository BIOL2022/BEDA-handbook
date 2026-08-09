script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
project_root <- dirname(dirname(script_path))
quarto_path <- file.path(project_root, "_quarto.yml")

read_source <- function(path) {
  stopifnot(file.exists(path))
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

quarto <- read_source(quarto_path)
stopifnot(!grepl("    - module02/202-timeline.qmd", quarto, fixed = TRUE))

partial_path <- file.path(project_root, "_partials", "module02-timeline.qmd")
html_path <- file.path(project_root, "module02", "202-timeline.qmd")
pdf_path <- file.path(project_root, "module02", "timeline-for-pdf.qmd")
changelog_path <- file.path(project_root, "module02", "202-timeline-changelog.qmd")
timeline_css_path <- file.path(project_root, "assets", "timeline.css")
filter_path <- file.path(project_root, "filters", "module2-timeline-typst.lua")
typst_partial_path <- file.path(project_root, "typst", "module2-timeline", "typst-show.typ")
generator_path <- file.path(project_root, "scripts", "make_timeline_pdf.R")

stopifnot(file.exists(partial_path), file.exists(changelog_path))

partial <- read_source(partial_path)
html <- read_source(html_path)
pdf <- read_source(pdf_path)
changelog <- read_source(changelog_path)
timeline_css <- read_source(timeline_css_path)
typst_filter <- read_source(filter_path)
typst_partial <- read_source(typst_partial_path)
generator <- read_source(generator_path)
partial_plain <- gsub("[[:space:]|]+", " ", partial)

include <- "{{< include ../_partials/module02-timeline.qmd >}}"
stopifnot(sum(gregexpr(include, html, fixed = TRUE)[[1]] > 0L) == 1L)
stopifnot(sum(gregexpr(include, pdf, fixed = TRUE)[[1]] > 0L) == 1L)
stopifnot(grepl("semester-status\\.js", html), !grepl("semester-status\\.js", pdf))
stopifnot(grepl("papersize: a4", pdf, fixed = TRUE))
stopifnot(grepl("pdf-standard: ua-1", pdf, fixed = TRUE))
stopifnot(grepl("../filters/module2-timeline-typst.lua", pdf, fixed = TRUE))
stopifnot(grepl("../typst/module2-timeline/typst-show.typ", pdf, fixed = TRUE))
stopifnot(!grepl("keep-typ", pdf, fixed = TRUE))

stopifnot(grepl('paper: "a4"', typst_partial, fixed = TRUE))
stopifnot(grepl("module2-timeline-support", typst_partial, fixed = TRUE))
stopifnot(grepl("module2-timeline-deadline", typst_partial, fixed = TRUE))
stopifnot(grepl("table.cell.where(y: 0)", typst_partial, fixed = TRUE))

stopifnot(grepl('source_path <- file.path(project_root, "module02", "timeline-for-pdf.qmd")', generator, fixed = TRUE))
stopifnot(grepl("module02-timeline.pdf", generator, fixed = TRUE))
stopifnot(grepl("quarto::quarto_render", generator, fixed = TRUE))
stopifnot(grepl('render_output_dir <- file.path(project_root, "_site", "module02")', generator, fixed = TRUE))
stopifnot(grepl("commandArgs(trailingOnly = TRUE)", generator, fixed = TRUE))
stopifnot(grepl("readBin", generator, fixed = TRUE))
stopifnot(grepl("file.rename(staged_output, output_path)", generator, fixed = TRUE))
stopifnot(!grepl("readLines|writeLines|file_move|library\\(fs\\)", generator))
stopifnot(!grepl("\\[[0-9]+:[0-9]+\\]", generator))

expected_support <- paste0(
  "**Equipment and technical help:** Contact the technical officer listed on Canvas ",
  "[here](https://canvas.sydney.edu.au/courses/74353/). Please include your project group name and practical time in your request."
)
stopifnot(grepl(expected_support, partial, fixed = TRUE))
stopifnot(grepl("202-timeline-changelog\\.qmd", partial))
stopifnot(grepl("202-timeline\\.qmd", changelog))

resources <- c(
  "[Module 2 introduction](201-intro.qmd)",
  "[Project information](203-projects.qmd)",
  "[Practical resources](205-resources.qmd)",
  "[Report instructions](204-report1.qmd)"
)
positions <- vapply(resources, regexpr, integer(1), text = partial, fixed = TRUE)
stopifnot(all(positions > 0L), identical(positions, sort(positions)))
stopifnot(grepl("Submission deadline", partial, fixed = TRUE))
stopifnot(grepl("Friday 25 September at 23:59", partial, fixed = TRUE))
stopifnot(grepl("**Submission deadline**\n**Friday 25 September at 23:59**", partial, fixed = TRUE))

for (hook in c("module2-timeline-meta", "module2-timeline-support", "module2-timeline-resources", "module2-timeline-deadline", "module2-timeline-table")) {
  stopifnot(grepl(hook, partial, fixed = TRUE))
}
stopifnot(grepl("module2-week-date", partial))
stopifnot(grepl(".module2-timeline-meta {\n  color: #536366;", timeline_css, fixed = TRUE))
stopifnot(grepl(".module2-week-date {\n  color: #536366;", timeline_css, fixed = TRUE))
stopifnot(grepl(".module2-timeline-table:focus-visible", timeline_css, fixed = TRUE))
stopifnot(grepl("outline: 3px solid #0f6b5b;", timeline_css, fixed = TRUE))
stopifnot(!grepl("<[^>]+>", partial))
stopifnot(!grepl("You are here", partial, fixed = TRUE))
stopifnot(!grepl("You are here", typst_filter, fixed = TRUE))
stopifnot(!grepl("You are here", typst_partial, fixed = TRUE))
stopifnot(!grepl("Week 9", partial, fixed = TRUE))
stopifnot(!grepl("Below is a brief timeline", partial, fixed = TRUE))

headers <- c("Week", "In your timetabled session", "Before the next session")
stopifnot(all(vapply(headers, grepl, logical(1), x = partial, fixed = TRUE)))
weeks <- c("Weeks 2–3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8")
dates <- c("10–23 August", "24–30 August", "31 August–6 September", "7–13 September", "14–20 September", "21–27 September")
stopifnot(all(vapply(weeks, grepl, logical(1), x = partial, fixed = TRUE)))
stopifnot(all(vapply(dates, grepl, logical(1), x = partial_plain, fixed = TRUE)))
stopifnot(grepl("Form your group", partial, fixed = TRUE))
stopifnot(grepl("Choose a direction", partial, fixed = TRUE))
stopifnot(grepl("There is no structured practical activity.", partial, fixed = TRUE))
stopifnot(grepl("One group member submits the group data file.", partial, fixed = TRUE))
stopifnot(grepl("Every student submits their individual report.", partial, fixed = TRUE))
stopifnot(grepl("sketch the expected graph", partial, fixed = TRUE))
stopifnot(grepl("Discuss what the pilot revealed", partial, fixed = TRUE))
stopifnot(grepl("supporting worksheets", partial, fixed = TRUE))
stopifnot(grepl("Friday 25 September at 23:59.", partial, fixed = TRUE))

rendered_path <- tempfile(fileext = ".html")
status <- system2(
  "quarto",
  c("pandoc", shQuote(partial_path), "--to", "html", "--standalone", "--output", shQuote(rendered_path)),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(status == 0, file.exists(rendered_path))
rendered <- read_source(rendered_path)
timeline_wrapper <- regmatches(
  rendered,
  regexpr("<div[^>]*module2-timeline-table[^>]*>", rendered, perl = TRUE)
)
stopifnot(length(timeline_wrapper) == 1L)
stopifnot(grepl('role="region"', timeline_wrapper, fixed = TRUE))
stopifnot(grepl('aria-label="Module 2 timeline"', timeline_wrapper, fixed = TRUE))
stopifnot(grepl('tabindex="0"', timeline_wrapper, fixed = TRUE))
header_cells <- gregexpr("<th(?: |>)[^>]*>", rendered, perl = TRUE)[[1]]
body <- sub("(?s).*<tbody[^>]*>", "", rendered, perl = TRUE)
body <- sub("(?s)</tbody>.*", "", body, perl = TRUE)
body_rows <- gregexpr("<tr(?: |>)[^>]*>", body, perl = TRUE)[[1]]
stopifnot(sum(header_cells > 0L) == 3L)
stopifnot(sum(body_rows > 0L) == 6L)
stopifnot(!grepl("colspan=", rendered, fixed = TRUE))

typst_path <- tempfile(fileext = ".typ")
status <- system2(
  "quarto",
  c(
    "pandoc",
    shQuote(partial_path),
    "--from", "markdown",
    "--to", "typst",
    paste0("--lua-filter=", shQuote(filter_path)),
    "--output", shQuote(typst_path)
  ),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(status == 0, file.exists(typst_path))
rendered_typst <- read_source(typst_path)
stopifnot(grepl("table.header", rendered_typst, fixed = TRUE))
stopifnot(grepl("#module2-timeline-table[", rendered_typst, fixed = TRUE))
stopifnot(!grepl("You are here", rendered_typst, fixed = TRUE))

canonical_links <- c(
  "https://biol2022.github.io/BEDA-handbook/module02/202-timeline-changelog.html",
  "https://biol2022.github.io/BEDA-handbook/module02/201-intro.html",
  "https://biol2022.github.io/BEDA-handbook/module02/203-projects.html",
  "https://biol2022.github.io/BEDA-handbook/module02/205-resources.html",
  "https://biol2022.github.io/BEDA-handbook/module02/204-report1.html"
)
stopifnot(all(vapply(canonical_links, grepl, logical(1), x = rendered_typst, fixed = TRUE)))
stopifnot(!grepl('.qmd")', rendered_typst, fixed = TRUE))

filter_cases_path <- tempfile(fileext = ".md")
writeLines(
  c(
    "[Introduction](201-intro.qmd#section)",
    "[Projects](./203-projects.qmd?view=1)"
  ),
  filter_cases_path,
  useBytes = TRUE
)
filter_cases_typst_path <- tempfile(fileext = ".typ")
status <- system2(
  "quarto",
  c(
    "pandoc",
    shQuote(filter_cases_path),
    "--from", "markdown",
    "--to", "typst",
    paste0("--lua-filter=", shQuote(filter_path)),
    "--output", shQuote(filter_cases_typst_path)
  ),
  stdout = FALSE,
  stderr = FALSE
)
stopifnot(status == 0, file.exists(filter_cases_typst_path))
filter_cases_typst <- read_source(filter_cases_typst_path)
stopifnot(grepl(
  "https://biol2022.github.io/BEDA-handbook/module02/201-intro.html#section",
  filter_cases_typst,
  fixed = TRUE
))
stopifnot(grepl(
  "https://biol2022.github.io/BEDA-handbook/module02/203-projects.html?view=1",
  filter_cases_typst,
  fixed = TRUE
))
stopifnot(!grepl("201-intro.qmd", filter_cases_typst, fixed = TRUE))
stopifnot(!grepl("203-projects.qmd", filter_cases_typst, fixed = TRUE))

integration_dir <- tempfile(pattern = "module2-timeline-integration-")
integration_cwd <- tempfile(pattern = "module2-timeline-cwd-")
dir.create(integration_dir)
dir.create(integration_cwd)
integration_pdf <- file.path(integration_dir, "module2-integration.pdf")
tracked_pdf <- file.path(project_root, "module02", "module02-timeline.pdf")
tracked_checksum <- unname(tools::md5sum(tracked_pdf))
render_output_dir <- file.path(project_root, "_site", "module02")
render_temps_before <- if (dir.exists(render_output_dir)) {
  list.files(
    render_output_dir,
    pattern = "^module02-timeline-render-.*\\.pdf$"
  )
} else {
  character()
}
integration_started <- proc.time()[["elapsed"]]
integration_log <- local({
  previous_cwd <- setwd(integration_cwd)
  on.exit(setwd(previous_cwd), add = TRUE)
  system2(
    "Rscript",
    c(shQuote(generator_path), shQuote(integration_pdf)),
    stdout = TRUE,
    stderr = TRUE
  )
})
integration_runtime <- proc.time()[["elapsed"]] - integration_started
integration_status <- attr(integration_log, "status")
if (is.null(integration_status)) {
  integration_status <- 0L
}
stopifnot(integration_status == 0L)
stopifnot(file.exists(integration_pdf), file.info(integration_pdf)$size > 1024)
stopifnot(identical(unname(tools::md5sum(tracked_pdf)), tracked_checksum))
render_temps_after <- list.files(
  render_output_dir,
  pattern = "^module02-timeline-render-.*\\.pdf$"
)
stopifnot(identical(sort(render_temps_after), sort(render_temps_before)))
stopifnot(length(list.files(
  integration_dir,
  pattern = "^\\.module2-integration\\.pdf-.*\\.pdf$"
)) == 0L)
integration_connection <- file(integration_pdf, open = "rb")
integration_signature <- rawToChar(readBin(
  integration_connection,
  what = "raw",
  n = 5L
))
close(integration_connection)
stopifnot(identical(integration_signature, "%PDF-"))

pdfinfo_path <- Sys.which("pdfinfo")
if (nzchar(pdfinfo_path)) {
  integration_pdfinfo <- system2(
    pdfinfo_path,
    shQuote(integration_pdf),
    stdout = TRUE,
    stderr = TRUE
  )
  stopifnot(is.null(attr(integration_pdfinfo, "status")))
  stopifnot(any(grepl("Page size:.*A4", integration_pdfinfo)))
  stopifnot(any(grepl("Tagged:.*yes", integration_pdfinfo)))

  integration_structure <- system2(
    pdfinfo_path,
    c("-struct-text", shQuote(integration_pdf)),
    stdout = TRUE,
    stderr = TRUE
  )
  stopifnot(is.null(attr(integration_structure, "status")))
  stopifnot(any(grepl(
    'H1 "Module 2 timeline" (block)',
    integration_structure,
    fixed = TRUE
  )))
}

pdftotext_path <- Sys.which("pdftotext")
if (nzchar(pdftotext_path)) {
  integration_text_path <- tempfile(fileext = ".txt")
  status <- system2(
    pdftotext_path,
    c("-layout", shQuote(integration_pdf), shQuote(integration_text_path)),
    stdout = FALSE,
    stderr = FALSE
  )
  stopifnot(status == 0, file.exists(integration_text_path))
  integration_text <- read_source(integration_text_path)
  stopifnot(grepl("Module 2 timeline", integration_text, fixed = TRUE))
  stopifnot(grepl("Submission deadline", integration_text, fixed = TRUE))
  stopifnot(grepl("Week 8", integration_text, fixed = TRUE))
}

stopifnot(grepl("schedule correction", changelog, ignore.case = TRUE))
stopifnot(grepl("three-column table", changelog, ignore.case = TRUE))
stopifnot(grepl("Week 6 project work", changelog, ignore.case = TRUE))
stopifnot(grepl("components together", changelog, ignore.case = TRUE))
stopifnot(grepl("accessible current-position marker", changelog, ignore.case = TRUE))

message("Module 2 timeline source contract passed.")
message(sprintf(
  "Generator integration render passed in %.2f seconds from %s.",
  integration_runtime,
  integration_cwd
))
