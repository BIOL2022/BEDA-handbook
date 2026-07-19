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
  if (matches[[1]] == -1L) 0L else length(matches)
}

has_line <- function(text, line) {
  line %in% strsplit(text, "\n", fixed = TRUE)[[1]]
}

front_matter_lines <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (length(lines) < 2L || lines[[1]] != "---") {
    return(character())
  }
  closing_offsets <- which(lines[-1L] == "---")
  if (length(closing_offsets) == 0L) {
    return(character())
  }
  closing_line <- closing_offsets[[1]] + 1L
  if (closing_line <= 2L) {
    return(character())
  }
  lines[seq.int(2L, closing_line - 1L)]
}

practical <- read_text("module01/102-week01.qmd")
workshop <- read_text("module01/w01-intro.qmd")

pilot_pages <- list("Practical 1" = practical, "Workshop 1" = workshop)
for (page_name in names(pilot_pages)) {
  page_front_matter <- front_matter_lines(pilot_pages[[page_name]])
  expect_true(
    sum(page_front_matter == "body-classes: manual-page") == 1L,
    paste(
      "Each Week 1 pilot page should opt into manual-page styling exactly once.",
      paste0("Page: ", page_name)
    )
  )
}

expected_activity_lines <- list(
  practical = c(
    "## [Workshop]{.manual-activity-label} Getting started (30 min) {.manual-activity #workshop-30-min}",
    "## [Activity]{.manual-activity-label} Your task {.manual-activity #your-task}",
    "## [Optional]{.manual-activity-label} Fancy a challenge? {.manual-activity .is-optional #fancy-a-challenge}"
  ),
  workshop = c(
    "## [Optional]{.manual-activity-label} Before the timed workshop: optional survey {.manual-activity .is-optional #before-the-timed-workshop-optional-survey}",
    "## [Activity]{.manual-activity-label} Workshop activities {.manual-activity #workshop-activities}",
    "## [Activity]{.manual-activity-label} Readiness checkpoints {.manual-activity #readiness-checkpoints}"
  )
)

for (line in expected_activity_lines$practical) {
  expect_true(has_line(practical, line), paste("Practical 1 is missing:", line))
}
for (line in expected_activity_lines$workshop) {
  expect_true(has_line(workshop, line), paste("Workshop 1 is missing:", line))
}
expect_true(
  match_count("{.manual-activity ", practical) == 3L,
  "Practical 1 should define exactly three activity headings."
)
expect_true(
  match_count("{.manual-activity ", workshop) == 3L,
  "Workshop 1 should define exactly three activity headings."
)

supporting_lines <- list(
  practical = c(
    "## Introduction",
    "## Quick recap: questions, variables and plots",
    "## Get ready",
    "## That is a wrap!"
  ),
  workshop = c(
    "## Software reference — not part of today's workshop"
  )
)
for (line in supporting_lines$practical) {
  expect_true(has_line(practical, line), paste("Practical supporting heading changed:", line))
}
for (line in supporting_lines$workshop) {
  expect_true(has_line(workshop, line), paste("Workshop supporting heading changed:", line))
}
expect_true(
  grepl("::: {.callout-note}\n## Example", practical, fixed = TRUE),
  "Practical Example should remain a callout within Your task."
)

label_pattern <- "\\[([^]]+)\\]\\{\\.manual-activity-label\\}"
labels <- c(
  unlist(regmatches(practical, gregexpr(label_pattern, practical, perl = TRUE))),
  unlist(regmatches(workshop, gregexpr(label_pattern, workshop, perl = TRUE)))
)
labels <- sub(label_pattern, "\\1", labels, perl = TRUE)
expect_true(
  identical(sort(unique(labels)), sort(c("Workshop", "Activity", "Optional"))),
  "Manual activity labels should use only Workshop, Activity, and Optional."
)

leading_indent <- function(line) {
  nchar(line) - nchar(sub("^[[:space:]]*", "", line))
}

yaml_list_at_path <- function(lines, path) {
  stack_keys <- character()
  stack_indents <- integer()
  nodes <- list()

  for (line_number in seq_along(lines)) {
    line <- sub("[[:space:]]+#.*$", "", lines[[line_number]])
    trimmed <- trimws(line)
    key_match <- regexec("^([A-Za-z0-9_-]+):[[:space:]]*$", trimmed)
    key_parts <- regmatches(trimmed, key_match)[[1]]
    if (length(key_parts) == 0L) {
      next
    }

    indent <- leading_indent(line)
    while (length(stack_indents) > 0L && tail(stack_indents, 1L) >= indent) {
      stack_keys <- head(stack_keys, -1L)
      stack_indents <- head(stack_indents, -1L)
    }
    node_path <- c(stack_keys, key_parts[[2]])
    nodes[[length(nodes) + 1L]] <- list(
      line = line_number,
      indent = indent,
      path = node_path
    )
    stack_keys <- node_path
    stack_indents <- c(stack_indents, indent)
  }

  matches <- Filter(function(node) identical(node$path, path), nodes)
  if (length(matches) != 1L) {
    return(list(path_count = length(matches), entries = character()))
  }

  node <- matches[[1]]
  block_lines <- integer()
  if (node$line < length(lines)) {
    for (line_number in seq.int(node$line + 1L, length(lines))) {
      line <- sub("[[:space:]]+#.*$", "", lines[[line_number]])
      if (!nzchar(trimws(line))) {
        next
      }
      indent <- leading_indent(line)
      if (indent <= node$indent) {
        break
      }
      block_lines <- c(block_lines, line_number)
    }
  }

  if (length(block_lines) == 0L) {
    return(list(path_count = 1L, entries = character()))
  }
  direct_indent <- min(vapply(lines[block_lines], leading_indent, integer(1)))
  direct_lines <- lines[block_lines][
    vapply(lines[block_lines], leading_indent, integer(1)) == direct_indent
  ]
  list_items <- trimws(direct_lines)
  list_items <- list_items[grepl("^-[[:space:]]+", list_items)]
  entries <- sub("^-[[:space:]]+", "", list_items)
  list(path_count = 1L, entries = entries)
}

project <- read_text("_quarto.yml")
project_lines <- strsplit(project, "\n", fixed = TRUE)[[1]]
html_css <- yaml_list_at_path(project_lines, c("format", "html", "css"))
expect_true(
  html_css$path_count == 1L &&
    length(html_css$entries) >= 2L &&
    sum(html_css$entries == "assets/timeline.css") == 1L &&
    sum(html_css$entries == "assets/manual-headings.css") == 1L &&
    identical(
      html_css$entries[seq_len(2L)],
      c("assets/timeline.css", "assets/manual-headings.css")
    ),
  "Quarto should load both global CSS files in order."
)
expect_true(
  file.exists("assets/manual-headings.css"),
  "assets/manual-headings.css should exist."
)
css <- read_text("assets/manual-headings.css")
css_without_comments <- gsub("/\\*[\\s\\S]*?\\*/", "", css, perl = TRUE)
css_lines <- strsplit(css_without_comments, "\n", fixed = TRUE)[[1]]
active_css_lines <- trimws(css_lines)

expected_colours <- c(
  "--manual-heading-accent" = "#6a5acd",
  "--manual-heading-ink" = "#27243a",
  "--manual-heading-paper" = "#fbfbfd",
  "--manual-heading-rule" = "#cbc7e4",
  "--manual-optional-bg" = "#eee3a7",
  "--manual-optional-ink" = "#4b4328"
)
colour_values <- character()
for (property in names(expected_colours)) {
  declaration <- paste0(property, ": ", expected_colours[[property]], ";")
  property_pattern <- paste0("^", property, ":[^;]+;$")
  declaration_lines <- grep(property_pattern, active_css_lines)
  expect_true(
    length(declaration_lines) == 1L &&
      active_css_lines[[declaration_lines]] == declaration,
    paste("Manual heading CSS should define exactly one active declaration:", declaration)
  )
  colour_values[[property]] <- sub(
    "^.*:[[:space:]]*(#[[:xdigit:]]{6});$",
    "\\1",
    active_css_lines[[declaration_lines]]
  )
}

for (token in c("@media (width <= 36rem)", "@media print")) {
  expect_true(
    grepl(token, css_without_comments, fixed = TRUE),
    paste("Manual heading CSS is missing:", token)
  )
}

print_css <- sub(
  "^[\\s\\S]*@media print[[:space:]]*\\{",
  "",
  css_without_comments,
  perl = TRUE
)
print_css <- paste(trimws(strsplit(print_css, "\n", fixed = TRUE)[[1]]), collapse = "\n")
print_label_selector_group <- paste(
  "body.manual-page main.content section.level2.manual-activity > h2.manual-activity > .manual-activity-label,",
  "body.manual-page main.content section.level2.manual-activity.is-optional > h2.manual-activity > .manual-activity-label",
  sep = "\n"
)
expect_true(
  grepl(print_label_selector_group, print_css, fixed = TRUE),
  "Print CSS should override both required and optional activity labels."
)

brace_depth_before <- integer(length(css_lines))
depth <- 0L
for (line_number in seq_along(css_lines)) {
  brace_depth_before[[line_number]] <- depth
  line <- css_lines[[line_number]]
  depth <- depth + nchar(gsub("[^{]", "", line))
  depth <- depth - nchar(gsub("[^}]", "", line))
}

rule_blocks <- function(selector) {
  starts <- which(
    trimws(css_lines) == paste0(selector, " {") &
      brace_depth_before == 0L
  )
  lapply(starts, function(start) {
    depth <- 0L
    block_end <- NA_integer_
    for (line_number in seq.int(start, length(css_lines))) {
      line <- css_lines[[line_number]]
      depth <- depth + nchar(gsub("[^{]", "", line))
      depth <- depth - nchar(gsub("[^}]", "", line))
      if (line_number > start && depth == 0L) {
        block_end <- line_number
        break
      }
    }
    if (is.na(block_end) || block_end <= start + 1L) {
      return(character())
    }
    trimws(css_lines[seq.int(start + 1L, block_end - 1L)])
  })
}

expect_rule <- function(selector, declarations) {
  blocks <- rule_blocks(selector)
  expect_true(
    any(vapply(blocks, function(block) all(declarations %in% block), logical(1))),
    paste("Manual heading CSS is missing the required rule block:", selector)
  )
}

expect_rule(
  "body.manual-page main.content section.level2 > h2:not(.manual-activity)",
  c(
    "border-bottom: 1px solid var(--manual-heading-rule);",
    "break-after: avoid;",
    "color: var(--manual-heading-ink);"
  )
)
expect_rule(
  "body.manual-page main.content section.level2.manual-activity",
  c(
    "margin-top: 2.75rem;",
    "padding-block: 0.1rem 0.25rem;",
    "padding-inline-start: 1rem;",
    "border-inline-start: 4px solid var(--manual-heading-accent);"
  )
)
expect_rule(
  "body.manual-page main.content section.level2.manual-activity.is-optional",
  "border-inline-start-color: var(--manual-optional-ink);"
)
expect_rule(
  "body.manual-page main.content section.level2.manual-activity > h2.manual-activity",
  c(
    "margin-top: 0;",
    "margin-bottom: 0.5rem;",
    "padding: 0;",
    "break-after: avoid;",
    "color: var(--manual-heading-ink);"
  )
)
expect_rule(
  "body.manual-page main.content section.level2.manual-activity > h2.manual-activity > .manual-activity-label",
  c(
    "display: inline-block;",
    "margin-right: 0.55rem;",
    "margin-bottom: 0.25rem;",
    "color: #fff;",
    "background: var(--manual-heading-accent);"
  )
)
expect_rule(
  "body.manual-page main.content section.level2.manual-activity.is-optional > h2.manual-activity > .manual-activity-label",
  c(
    "border: 1px solid var(--manual-optional-ink);",
    "color: var(--manual-optional-ink);",
    "background: var(--manual-optional-bg);"
  )
)
inline_code_selector <- "body.manual-page main.content section.level2.manual-activity :not(pre) > code"
inline_code_blocks <- rule_blocks(inline_code_selector)
expect_true(
  length(inline_code_blocks) == 1L &&
    identical(
      inline_code_blocks[[1]],
      c(
        "white-space: normal;",
        "overflow-wrap: anywhere;"
      )
    ),
  paste("Manual heading CSS should contain the exact inline-code wrapping rule:", inline_code_selector)
)
expect_rule(
  "body.manual-page main.content section.level2 > h2 .anchorjs-link:focus-visible",
  c(
    "outline: 3px solid currentColor;",
    "outline-offset: 3px;"
  )
)

expect_true(
  !grepl("body.manual-page h2", css_without_comments, fixed = TRUE),
  "Manual CSS should not use a broad body.manual-page h2 selector."
)
expect_true(
  !grepl(".manual-page .manual-activity", css_without_comments, fixed = TRUE),
  "Manual CSS should not use a broad .manual-page .manual-activity selector."
)

normalize_declaration <- function(declaration) {
  tolower(gsub("\\s+", "", declaration))
}

activity_heading_blocks <- c(
  rule_blocks(
    "body.manual-page main.content section.level2.manual-activity > h2.manual-activity"
  ),
  rule_blocks(
    "body.manual-page main.content section.level2 > h2.manual-activity"
  )
)
activity_heading_declarations <- unlist(activity_heading_blocks, use.names = FALSE)
activity_heading_properties <- sub(
  ":.*$",
  "",
  vapply(activity_heading_declarations, normalize_declaration, character(1))
)
expect_true(
  !any(grepl(
    paste0(
      "^border(?:-(?:width|style|color)|",
      "-(?:top|right|bottom|left|block(?:-(?:start|end))?|",
      "inline(?:-(?:start|end))?)(?:-(?:width|style|color))?)?$"
    ),
    activity_heading_properties,
    perl = TRUE
  )),
  "Activity headings should not use the rejected enclosing box."
)

activity_label_blocks <- c(
  rule_blocks(
    paste0(
      "body.manual-page main.content section.level2.manual-activity > ",
      "h2.manual-activity > .manual-activity-label"
    )
  ),
  rule_blocks(
    paste0(
      "body.manual-page main.content section.level2 > ",
      "h2.manual-activity > .manual-activity-label"
    )
  )
)
activity_label_declarations <- vapply(
  unlist(activity_label_blocks, use.names = FALSE),
  normalize_declaration,
  character(1)
)
activity_label_position_values <- activity_label_declarations[
  grepl("^position:", activity_label_declarations)
]
activity_label_position_values <- sub(
  "^position:",
  "",
  activity_label_position_values
)
activity_label_position_values <- sub(";.*$", "", activity_label_position_values)
activity_label_position_values <- sub("!important$", "", activity_label_position_values)
expect_true(
  !any(activity_label_position_values %in% c("absolute", "fixed")),
  "Activity labels should remain in normal heading flow."
)

relative_luminance <- function(hex) {
  channels <- strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), base = 16L) / 255
  channels <- ifelse(
    channels <= 0.04045,
    channels / 12.92,
    ((channels + 0.055) / 1.055)^2.4
  )
  sum(channels * c(0.2126, 0.7152, 0.0722))
}

contrast_ratio <- function(first, second) {
  luminances <- c(relative_luminance(first), relative_luminance(second))
  (max(luminances) + 0.05) / (min(luminances) + 0.05)
}

expect_true(
  contrast_ratio("#ffffff", colour_values[["--manual-heading-accent"]]) >= 4.5,
  "Required activity label text should meet 4.5:1 contrast."
)
expect_true(
  contrast_ratio(
    colour_values[["--manual-optional-ink"]],
    colour_values[["--manual-optional-bg"]]
  ) >= 4.5,
  "Optional activity label text should meet 4.5:1 contrast."
)
expect_true(
  contrast_ratio(
    colour_values[["--manual-heading-accent"]],
    colour_values[["--manual-heading-paper"]]
  ) >= 3,
  "Required activity rails should meet 3:1 contrast."
)
expect_true(
  contrast_ratio(
    colour_values[["--manual-optional-ink"]],
    colour_values[["--manual-heading-paper"]]
  ) >= 3,
  "Optional activity rails should meet 3:1 contrast."
)

verify_rendered_contract <- function() {
  previous_directory <- getwd()
  fixture_root <- tempfile("manual-headings-")
  dir.create(fixture_root, recursive = TRUE)
  on.exit({
    setwd(previous_directory)
    unlink(fixture_root, recursive = TRUE)
  }, add = TRUE)

writeLines(c(
  "project:",
  "  type: website",
  "  render:",
  "    - numbered.qmd",
  "    - unnumbered.qmd",
  "    - control.qmd",
  "format:",
  "  html:",
  "    toc: true"
), file.path(fixture_root, "_quarto.yml"), useBytes = TRUE)

writeLines(c(
  "---",
  "title: Numbered manual",
  "body-classes: manual-page",
  "number-sections: true",
  "---",
  "",
  "## Introduction",
  "",
  "Supporting text.",
  "",
  "## [Activity]{.manual-activity-label} Your task {.manual-activity #your-task}",
  "",
  "Activity text."
), file.path(fixture_root, "numbered.qmd"), useBytes = TRUE)

writeLines(c(
  "---",
  "title: Unnumbered manual",
  "body-classes: manual-page",
  "number-sections: false",
  "---",
  "",
  "## [Optional]{.manual-activity-label} Extra practice {.manual-activity .is-optional #extra-practice}",
  "",
  "Optional text."
), file.path(fixture_root, "unnumbered.qmd"), useBytes = TRUE)

writeLines(c(
  "---",
  "title: Control page",
  "---",
  "",
  "## Introduction"
), file.path(fixture_root, "control.qmd"), useBytes = TRUE)

setwd(fixture_root)
render_output <- suppressWarnings(system2(
  "quarto",
  "render",
  stdout = TRUE,
  stderr = TRUE
))
render_status <- attr(render_output, "status")
if (is.null(render_status)) render_status <- 0L
setwd(previous_directory)
expect_true(render_status == 0L, paste(render_output, collapse = "\n"))

numbered <- read_text(file.path(fixture_root, "_site", "numbered.html"))
unnumbered <- read_text(file.path(fixture_root, "_site", "unnumbered.html"))
control <- read_text(file.path(fixture_root, "_site", "control.html"))

expect_true(
  grepl('<body class="[^"]*manual-page', numbered, perl = TRUE),
  "The manual-page body class should survive Quarto rendering."
)
expect_true(
  grepl('<section id="your-task" class="[^"]*level2[^"]*manual-activity', numbered, perl = TRUE),
  "Quarto should copy manual-activity to the level-two section."
)
expect_true(
  grepl('<h2 class="[^"]*manual-activity[^"]*anchored"[^>]*data-anchor-id="your-task"', numbered, perl = TRUE),
  "Quarto should preserve manual-activity and data-anchor-id on the heading."
)
expect_true(
  grepl('<span class="manual-activity-label">Activity</span> Your task', numbered, fixed = TRUE),
  "The activity label should render as real heading text."
)
expect_true(
  match_count('<span class="manual-activity-label">Activity</span>', numbered) == 2L,
  "The activity label should appear once in the heading and once in the TOC."
)
expect_true(
  grepl('href="#your-task"', numbered, fixed = TRUE),
  "The TOC should retain the explicit activity anchor."
)
expect_true(
  grepl('<span class="header-section-number">', numbered, fixed = TRUE),
  "The numbered practical fixture should retain a section-number span."
)
expect_true(
  !grepl('<span class="header-section-number">', unnumbered, fixed = TRUE),
  "The unnumbered workshop fixture should not gain section numbers."
)
expect_true(
  grepl(
    paste0(
      '<section id="extra-practice"',
      '(?=[^>]*class="(?=[^"]*\\blevel2\\b)',
      '(?=[^"]*\\bmanual-activity\\b)',
      '(?=[^"]*\\bis-optional\\b)[^"]*")[^>]*>'
    ),
    unnumbered,
    perl = TRUE
  ),
  "The optional activity classes should propagate to the level-two section."
)
expect_true(
  grepl(
    paste0(
      '<h2(?=[^>]*class="(?=[^"]*\\bmanual-activity\\b)',
      '(?=[^"]*\\bis-optional\\b)(?=[^"]*\\banchored\\b)[^"]*")',
      '(?=[^>]*data-anchor-id="extra-practice")[^>]*>',
      '(?:(?!</h2>)[\\s\\S])*?',
      '<span class="manual-activity-label">Optional</span>'
    ),
    unnumbered,
    perl = TRUE
  ),
  "The optional activity classes and real label should propagate to the heading."
)
expect_true(
  !grepl('<body class="[^"]*manual-page', control, perl = TRUE),
  "A non-manual control page should not receive the manual-page class."
)
}

verify_rendered_contract()

cat(sprintf("PASS: Manual heading contract (%d checks)\n", checks))
