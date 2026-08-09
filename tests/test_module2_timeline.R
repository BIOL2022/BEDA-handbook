script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
project_root <- dirname(dirname(script_path))

read_source <- function(path) {
  stopifnot(file.exists(path))
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

partial_path <- file.path(project_root, "_partials", "module02-timeline.qmd")
html_path <- file.path(project_root, "module02", "202-timeline.qmd")
pdf_path <- file.path(project_root, "module02", "timeline-for-pdf.qmd")
changelog_path <- file.path(project_root, "module02", "202-timeline-changelog.qmd")

stopifnot(file.exists(partial_path), file.exists(changelog_path))

partial <- read_source(partial_path)
html <- read_source(html_path)
pdf <- read_source(pdf_path)
changelog <- read_source(changelog_path)
partial_plain <- gsub("[[:space:]|]+", " ", partial)

include <- "{{< include ../_partials/module02-timeline.qmd >}}"
stopifnot(sum(gregexpr(include, html, fixed = TRUE)[[1]] > 0L) == 1L)
stopifnot(sum(gregexpr(include, pdf, fixed = TRUE)[[1]] > 0L) == 1L)
stopifnot(grepl("semester-status\\.js", html), !grepl("semester-status\\.js", pdf))

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
stopifnot(!grepl("<[^>]+>", partial))
stopifnot(!grepl("You are here", partial, fixed = TRUE))
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
header_cells <- gregexpr("<th(?: |>)[^>]*>", rendered, perl = TRUE)[[1]]
body <- sub("(?s).*<tbody[^>]*>", "", rendered, perl = TRUE)
body <- sub("(?s)</tbody>.*", "", body, perl = TRUE)
body_rows <- gregexpr("<tr(?: |>)[^>]*>", body, perl = TRUE)[[1]]
stopifnot(sum(header_cells > 0L) == 3L)
stopifnot(sum(body_rows > 0L) == 6L)
stopifnot(!grepl("colspan=", rendered, fixed = TRUE))

stopifnot(grepl("schedule correction", changelog, ignore.case = TRUE))
stopifnot(grepl("three-column table", changelog, ignore.case = TRUE))
stopifnot(grepl("Week 6 project work", changelog, ignore.case = TRUE))
stopifnot(grepl("components together", changelog, ignore.case = TRUE))
stopifnot(grepl("accessible current-position marker", changelog, ignore.case = TRUE))

message("Module 2 timeline source contract passed.")
