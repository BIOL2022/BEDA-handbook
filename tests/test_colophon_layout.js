#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const pdf = path.join(
  repoRoot,
  "_book",
  "Biology-Experimental-Design-and-Analysis.pdf",
);
const bbox = execFileSync(
  "pdftotext",
  ["-f", "2", "-l", "2", "-bbox", pdf, "-"],
  { encoding: "utf8" },
);
const words = [...bbox.matchAll(/<word\b([^>]*)>([^<]*)<\/word>/g)].map(
  ([, attributes, text]) => ({
    text,
    yMin: Number(attributes.match(/\byMin="([^"]+)"/)?.[1]),
  }),
);
const headingIndex = words.findIndex(
  (word, index) =>
    word.text === "About" &&
    words[index + 1]?.text === "this" &&
    words[index + 2]?.text === "edition",
);

assert.notEqual(headingIndex, -1, "missing colophon H1 on physical page 2");
assert.ok(
  words[headingIndex].yMin < 180,
  `colophon H1 begins too low: y=${words[headingIndex].yMin.toFixed(1)}pt`,
);

console.log(
  `PASS: colophon H1 begins at y=${words[headingIndex].yMin.toFixed(1)}pt`,
);
