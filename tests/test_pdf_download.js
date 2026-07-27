#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const pdfHref = "downloads/BIOL2022-unit-handbook.pdf";
const pdfIcon = '<i class="bi bi-file-earmark-pdf" aria-hidden="true"></i>';
const pdfLabel = "Download PDF handbook";
const pdfLink = `[${pdfIcon} ${pdfLabel}](${pdfHref}){.handbook-download-link}`;

function read(file) {
  return fs.readFileSync(path.join(repoRoot, file), "utf8");
}

function yamlBlock(source, key, indentation) {
  const lines = source.split(/\r?\n/);
  const prefix = " ".repeat(indentation);
  const start = lines.findIndex((line) => line === `${prefix}${key}:`);
  assert.notEqual(start, -1, `missing YAML block: ${key}`);

  let end = start + 1;
  while (end < lines.length) {
    const line = lines[end];
    if (line.trim().length > 0) {
      const lineIndentation = line.match(/^ */)[0].length;
      if (lineIndentation <= indentation) {
        break;
      }
    }
    end += 1;
  }
  return lines.slice(start, end).join("\n");
}

function assertPdfLink(source, location) {
  assert.equal(
    source.split(pdfLink).length - 1,
    1,
    `${location} must contain one exact PDF handbook link`,
  );

  const linkLine = source
    .split(/\r?\n/)
    .find((line) => line.includes(`](${pdfHref})`));
  assert.ok(linkLine, `${location} is missing the PDF handbook href`);

  const suffix = linkLine.slice(
    linkLine.indexOf(`](${pdfHref})`) + `](${pdfHref})`.length,
  );
  assert.doesNotMatch(
    suffix,
    /(?:^|[\s{])(?:target|download)(?:=|\s|})/i,
    `${location} PDF link must open normally without target or download`,
  );
}

const homepage = read("index.qmd");
const about = read("about-handbook.qmd");
const quarto = read("_quarto.yml");

assertPdfLink(homepage, "homepage");
const homepageLinkIndex = homepage.indexOf(pdfLink);
const scheduleIndex = homepage.indexOf(
  "{{< include _partials/weekly-schedule.qmd >}}",
);
assert.notEqual(scheduleIndex, -1, "homepage is missing the weekly schedule");
assert.ok(
  homepageLinkIndex < scheduleIndex,
  "homepage PDF link must appear before the weekly schedule",
);

assertPdfLink(about, "About page");
const aboutLinkIndex = about.indexOf(pdfLink);
const editionIndex = about.indexOf("{{< meta edition-year >}}**");
const colophonIndex = about.indexOf(
  "{{< include _partials/colophon-content.qmd >}}",
);
assert.notEqual(editionIndex, -1, "About page is missing the edition metadata");
assert.notEqual(colophonIndex, -1, "About page is missing the colophon include");
assert.ok(
  editionIndex < aboutLinkIndex && aboutLinkIndex < colophonIndex,
  "About page PDF link must appear between edition details and the colophon",
);

assert.match(
  quarto,
  /^\s+- assets\/handbook-download\.css$/m,
  "Quarto must include the PDF download stylesheet",
);
const navbarBlock = yamlBlock(quarto, "navbar", 2);
assert.doesNotMatch(
  navbarBlock,
  /BIOL2022-unit-handbook\.pdf|Download PDF handbook/,
  "PDF handbook link must remain out of the navbar",
);

const css = read("assets/handbook-download.css");
assert.doesNotMatch(css, /\bcolou?r\s*:/i, "PDF link CSS must inherit its colour");
assert.doesNotMatch(
  css,
  /\boutline\s*:\s*(?:none|0(?:\D|$))/i,
  "PDF link CSS must not suppress focus outlines",
);

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), "beda-handbook-pdf-"),
);

try {
  const script = path.join(repoRoot, "scripts/stage-handbook-pdf.sh");
  const source = path.join(temporaryDirectory, "source.pdf");
  const destination = path.join(
    temporaryDirectory,
    "nested",
    "BIOL2022-unit-handbook.pdf",
  );
  const fixture = Buffer.from("%PDF-1.7\nhandbook fixture\n", "utf8");

  fs.writeFileSync(source, fixture);
  const successfulRun = childProcess.spawnSync(
    "bash",
    [script, source, destination],
    { encoding: "utf8" },
  );
  assert.equal(
    successfulRun.status,
    0,
    `staging a non-empty PDF failed: ${successfulRun.stderr}`,
  );
  assert.deepEqual(
    fs.readFileSync(destination),
    fixture,
    "staged PDF must match its source byte-for-byte",
  );

  const emptySource = path.join(temporaryDirectory, "empty.pdf");
  const emptyDestination = path.join(temporaryDirectory, "empty-output.pdf");
  fs.writeFileSync(emptySource, Buffer.alloc(0));
  const emptyRun = childProcess.spawnSync(
    "bash",
    [script, emptySource, emptyDestination],
    { encoding: "utf8" },
  );
  assert.notEqual(
    emptyRun.status,
    0,
    "staging an empty PDF must exit nonzero",
  );
  assert.match(
    emptyRun.stderr,
    /Expected a non-empty handbook PDF/,
    "empty PDF failure must explain that a non-empty PDF is required",
  );
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}

const workflow = read(".github/workflows/publish.yml");
const bookRenderIndex = workflow.search(
  /^\s+run: quarto render --profile book\s*$/m,
);
const websiteRenderIndex = workflow.search(/^\s+run: quarto render\s*$/m);
const stagePdfIndex = workflow.search(
  /^\s+run: bash scripts\/stage-handbook-pdf\.sh\s*$/m,
);
const publishIndex = workflow.search(
  /^\s+uses: quarto-dev\/quarto-actions\/publish@v2\s*$/m,
);

assert.notEqual(
  bookRenderIndex,
  -1,
  "publish workflow must render the Typst handbook",
);
assert.notEqual(
  websiteRenderIndex,
  -1,
  "publish workflow must render the website separately",
);
assert.notEqual(
  stagePdfIndex,
  -1,
  "publish workflow must stage the PDF download",
);
assert.notEqual(
  publishIndex,
  -1,
  "publish workflow must use the Quarto publish action",
);
assert.ok(
  bookRenderIndex < websiteRenderIndex &&
    websiteRenderIndex < stagePdfIndex &&
    stagePdfIndex < publishIndex,
  "publish workflow must render the handbook, render the website, stage the PDF, then publish",
);

const publishStep = workflow.slice(publishIndex);
assert.match(
  publishStep,
  /with:\s*\n\s+target: gh-pages\s*\n\s+render: false(?:\s*\n|$)/,
  "publish action must deploy the pre-rendered site to gh-pages",
);
assert.match(
  publishStep,
  /env:\s*\n\s+GITHUB_TOKEN: \$\{\{ secrets\.GITHUB_TOKEN \}\}/,
  "publish action must receive the GitHub token",
);

console.log("PASS: PDF handbook download source contract");
