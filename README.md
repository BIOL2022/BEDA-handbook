# Welcome to BEDA

**BEDA** is **BIOL2022 Biology Experimental Design and Analysis**. We are a Unit of Study at the University of Sydney. This repository contains the BEDA Handbook - an open-access, online resource for students.

Use this handbook to navigate BIOL2022 — it contains weekly practicals, assessment briefs and rubrics, cheatsheets, and links to all the lectures.

**Front page:** https://biol2022.github.io/BEDA-handbook

**Schedule authors:** see [data/README.md](data/README.md) before editing the weekly schedule.

## Rendering the handbook

Install [Quarto 1.9 or later](https://quarto.org/) and R before rendering.

- Run `quarto render --profile book` to build the Typst handbook at
  `_book/Biology-Experimental-Design-and-Analysis.pdf`.
- Run `quarto render` to build the website in `_site`.
- Run `bash scripts/stage-handbook-pdf.sh` to copy the current handbook to
  `_site/downloads/BIOL2022-unit-handbook.pdf`.

## Updating the edition

Update the values in `_edition.yml` when preparing a new teaching year. Working
tags use `vYYYY.x`; the final archival tag uses `vYYYY`. When the final tag is
created, update `edition-citation-url` to the tagged repository URL, then render
both outputs and run the edition and colophon tests:

- `node tests/test_edition_metadata.js`
- `node tests/test_colophon_source.js`
- `node tests/test_colophon_rendered.js`
- `node tests/test_colophon_layout.js`
- `node tests/test_colophon_pdf.js`
- `node tests/test_pdf_download.js`
