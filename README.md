# Welcome to BEDA

**BEDA** is **BIOL2022 Biology Experimental Design and Analysis**. We are a Unit of Study at the University of Sydney. This repository contains the BEDA Handbook - an open-access, online resource for students.

Use this handbook to navigate BIOL2022 — it contains weekly practicals, assessment briefs and rubrics, cheatsheets, and links to all the lectures.

**Front page:** https://biol2022.github.io/BEDA-handbook

**Schedule authors:** see [data/README.md](data/README.md) before editing the weekly schedule.

## Rendering the handbook

Use [Quarto 1.9.37](https://quarto.org/) and R 4.6.1 to match the automated
builds. The project requires at least Quarto 1.9.17 for its bundled Typst book
format.

Restore the recorded R package versions before rendering:

```r
renv::restore()
```

The project uses `renv.lock` and an isolated package library. Opening the RStudio
project activates it automatically. On a fresh checkout, renv bootstraps itself;
then run `renv::restore()` to install the locked packages. Frozen output speeds
up builds but does not replace these dependencies. Check the environment with
`Rscript scripts/check-r-environment.R`.

To deliberately change dependencies, update `DESCRIPTION`, install or update
only the intended packages, render the affected pages, and run
`renv::snapshot()`. Review and commit the resulting lockfile with the change.
The automated build restores this same lockfile rather than installing the
latest packages. See the [renv workflow](https://rstudio.github.io/renv/articles/renv.html).

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

Update the edition labels and citation in `_edition.yml`. The year, semester,
teaching periods, and Canvas/Ed course URLs live in `_semester.json`, which
Quarto also loads as project metadata. Preserve both break end dates:
`displayEnd` is the date shown in the weekly schedule; `end` includes the weekend
and any holiday before teaching resumes.

Run `node scripts/sync-semester-settings.mjs` after changing semester settings.
It updates the browser configuration and schedule-break CSV; normal Quarto
renders also run it automatically. CI checks that generated files are current.
The website, Canvas embed, and daily SVG refresh share the same calendar logic.
Use `canvas:/pages/...`, `canvas:/files/...`, or `canvas:/assignments/...` in
Quarto sources and `data/weekly_content.csv`; `canvas:` links to the course home.
These resolve to the configured course URL during rendering. `ed:` works the
same way. Page slugs, assignment/file IDs, assessment deadlines, and year-specific
resource labels still need checking when rolling over to a new cohort.

Working tags use `vYYYY.x`; the final archival tag uses `vYYYY`. When the final
tag is created, update `edition-citation-url` to the tagged repository URL,
then render both outputs.

## Media

Keep image and video paths, dimensions, and embedded-player markup stable when
optimising existing assets. Use conservative image compression and H.264 video
with audio copied unchanged and MP4 metadata at the start for streaming.
Compare compressed videos with their originals and retain originals whenever
compression makes them larger or noticeably reduces legibility.
