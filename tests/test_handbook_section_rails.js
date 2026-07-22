#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "unit-information.qmd"), "utf8");
const headings = source.split(/\r?\n/).filter((line) => line.startsWith("## "));

assert.ok(headings.length > 0, "unit-information.qmd should contain level-two headings");
for (const heading of headings) {
  assert.match(heading, /\{\.section-rail\}\s*$/, `Missing section rail: ${heading}`);
}

const css = fs.readFileSync(path.join(root, "assets", "timeline.css"), "utf8");
assert.match(css, /main\.content section\.level2\.section-rail/);
assert.match(css, /border-inline-start:\s*4px solid #6B210F/);
assert.match(css, /padding-inline-start:\s*1rem/);
assert.match(css, /@media \(width <= 36rem\)/);
assert.match(css, /@media print/);

console.log("PASS: handbook section rail source contract");
