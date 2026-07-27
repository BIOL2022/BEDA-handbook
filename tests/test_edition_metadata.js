#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { edition } = require("./helpers/edition_metadata.js");

const repoRoot = path.resolve(__dirname, "..");

function read(file) {
  return fs.readFileSync(path.join(repoRoot, file), "utf8");
}

const quarto = read("_quarto.yml");
const typstShow = read("typst/typst-show.typ");

const requiredFields = [
  "edition-number",
  "edition-label",
  "edition-citation-label",
  "edition-semester",
  "edition-year",
  "edition-archive-tag",
  "edition-citation-url",
];
for (const field of requiredFields) {
  assert.ok(
    Object.hasOwn(edition, field),
    `_edition.yml is missing required field: ${field}`,
  );
}

assert.ok(
  Number.isInteger(edition["edition-number"]) && edition["edition-number"] > 0,
  "edition-number must be a positive integer",
);
assert.ok(
  typeof edition["edition-label"] === "string" &&
    edition["edition-label"].trim().length > 0,
  "edition-label must be a non-empty string",
);
assert.ok(
  typeof edition["edition-citation-label"] === "string" &&
    edition["edition-citation-label"].trim().length > 0,
  "edition-citation-label must be a non-empty string",
);
assert.ok(
  Number.isInteger(edition["edition-semester"]) &&
    edition["edition-semester"] >= 1 &&
    edition["edition-semester"] <= 3,
  "edition-semester must be an integer from 1 to 3",
);
assert.match(
  String(edition["edition-year"]),
  /^\d{4}$/,
  "edition-year must be a four-digit year",
);
assert.ok(
  Number.isInteger(edition["edition-year"]),
  "edition-year must be an integer",
);
assert.ok(
  typeof edition["edition-archive-tag"] === "string",
  "edition-archive-tag must be a string",
);
assert.equal(
  edition["edition-archive-tag"],
  `v${edition["edition-year"]}`,
  "edition-archive-tag must match the edition year",
);
assert.doesNotThrow(() => {
  assert.equal(
    typeof edition["edition-citation-url"],
    "string",
    "edition-citation-url must be a string",
  );
  const url = new URL(edition["edition-citation-url"]);
  assert.ok(
    url.protocol === "http:" || url.protocol === "https:",
    "edition-citation-url must use http or https",
  );
});

assert.match(quarto, /^metadata-files:\n  - _edition\.yml$/m);
assert.match(
  typstShow,
  /Semester \$edition-semester\$ · \$edition-year\$/,
);
assert.doesNotMatch(typstShow, /#"\$date\$"\.replace\(",", " ·"\)/);

console.log("PASS: edition metadata source contract");
