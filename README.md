# Welcome to BEDA

**BEDA** is **BIOL2022 Biology Experimental Design and Analysis**. We are a Unit of Study at the University of Sydney. This repository contains the BEDA Handbook - an open-access, online resource for students.

Use this handbook to navigate BIOL2022 — it contains weekly practicals, assessment briefs and rubrics, cheatsheets, and links to all the lectures.

**Front page:** https://biol2022.github.io/BEDA-handbook

**Schedule authors:** see [data/README.md](data/README.md) before editing the weekly schedule.

## Rendering the handbook

Use [Quarto 1.9.37](https://quarto.org/) and R 4.6.1 to match the automated
builds. The project requires at least Quarto 1.9.17 for its bundled Typst book
format.

Install the R packages used by the handbook before rendering changed
computational pages. Frozen output speeds up builds but does not replace these
dependencies:

```r
install.packages(c(
  "knitr", "rmarkdown", "ggplot2", "tidyverse", "palmerpenguins",
  "patchwork", "readxl", "gt"
))
```

- Run `quarto render --profile book` to build the Typst handbook at
  `_book/Biology-Experimental-Design-and-Analysis.pdf`.
- Run `quarto render` to build the website in `_site`.
- Run `bash scripts/stage-handbook-pdf.sh` to copy the current handbook to
  `_site/downloads/BIOL2022-unit-handbook.pdf` and
  `_pdf/Biology-Experimental-Design-and-Analysis.pdf`.
- Run `node scripts/check_navigation.js _site` after rendering to check local
  links, navigation, and the desktop and mobile weekly schedules.

Pull requests run the build and navigation checks without publishing. Pushes
to `main` and manual publish runs deploy after these checks pass. Publication
and the daily Canvas status refresh share a queue so they cannot write to
`gh-pages` at the same time.

Paths in `project.resources` start with `/` to match only files at the project
root. Keep that prefix: an unanchored path also matches copies under other
profiles' output directories.

## Updating the edition

Update the values in `_edition.yml` when preparing a new teaching year. Working
tags use `vYYYY.x`; the final archival tag uses `vYYYY`. When the final tag is
created, update `edition-citation-url` to the tagged repository URL, then render
both outputs.

The semester calendar is also maintained in `scripts/semester-status.js`,
`scripts/generate-semester-status-svg.mjs`, `canvas/semester-status.html`, and
`data/semester_breaks.csv`. Update those dates and the SVG generator's default
year and semester together. Check Canvas and Ed course links throughout the
source when rolling over to a new cohort.
