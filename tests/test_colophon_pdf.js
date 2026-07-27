#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const {
  colophonEditionLabel,
  edition,
} = require("./helpers/edition_metadata.js");

const repoRoot = path.resolve(__dirname, "..");
const pdf = path.join(
  repoRoot,
  "_book",
  "Biology-Experimental-Design-and-Analysis.pdf",
);
const commandOptions = {
  cwd: repoRoot,
  encoding: "utf8",
  maxBuffer: 64 * 1024 * 1024,
};

function extractPage(page) {
  return execFileSync(
    "pdftotext",
    ["-f", String(page), "-l", String(page), "-layout", pdf, "-"],
    commandOptions,
  );
}

const page2 = extractPage(2);
assert.match(page2, /About this edition/);
assert.ok(
  page2.includes(colophonEditionLabel),
  `physical page 2 is missing edition label: ${colophonEditionLabel}`,
);
assert.doesNotMatch(
  page2,
  /^\s*2\s*$/m,
  "physical page 2 must not print a standalone page number",
);
assert.doesNotMatch(
  page2,
  /repository\s+\./,
  "the repository link must not leave a space before its full stop",
);
assert.doesNotMatch(
  page2,
  /licence\s+\./,
  "the licence link must not leave a space before its full stop",
);

const page3 = extractPage(3);
assert.match(page3, /Contents/);
assert.match(
  page3,
  /^\s*3\s*$/m,
  "physical page 3 must retain its standalone printed page number",
);
assert.doesNotMatch(page3, /About this edition/);

const allText = execFileSync("pdftotext", [pdf, "-"], commandOptions);
assert.equal(
  (allText.match(/About this edition/g) || []).length,
  1,
  "the colophon title must occur exactly once in the rendered book",
);

const structure = execFileSync(
  "pdfinfo",
  ["-struct-text", pdf],
  commandOptions,
);
assert.match(
  structure,
  /^\s*H1 "About this edition"(?:\s|\()/m,
  "the colophon title must be a logical H1",
);

const urls = execFileSync("pdfinfo", ["-url", pdf], commandOptions);
const page2Urls = new Set(
  urls
    .split(/\r?\n/)
    .map((line) => line.match(/^\s*(\d+)\s+\S+\s+(.+?)\s*$/))
    .filter((match) => match && Number(match[1]) === 2)
    .map((match) => match[2]),
);
for (const url of [
  "https://creativecommons.org/licenses/by/4.0/",
  "https://github.com/BIOL2022/BEDA-handbook",
  edition["edition-citation-url"],
  "https://biol2022.github.io/BEDA-handbook/updates.html",
]) {
  assert.ok(
    page2Urls.has(url),
    `missing exact physical-page-2 link annotation: ${url}\n` +
      `found: ${[...page2Urls].join(", ")}`,
  );
}

console.log("PASS: rendered Typst colophon contract");
