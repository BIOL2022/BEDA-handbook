#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");

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

const partial = read("_partials/colophon-content.qmd");
const wrapper = read("about-handbook.qmd");
const quarto = read("_quarto.yml");
const quartoBook = read("_quarto-book.yml");
const unitInformation = read("unit-information.qmd");
const homepage = read("index.qmd");
const readme = read("README.md");

assert.doesNotMatch(partial, /^# /m);
for (const heading of [
  "Authors",
  "How this book was built",
  "Rendering the handbook",
  "Licence",
  "Suggested citation",
]) {
  assert.match(partial, new RegExp(`^## ${heading}$`, "m"));
}

assert.match(
  partial,
  /^Januar Harianto · Clare McArthur · Matthew Crowther$/m,
);
assert.doesNotMatch(partial, /\b(?:Dr|Professor|Prof)\.?\s/);
for (const shortcode of [
  "{{< meta edition-year >}}",
  "{{< meta edition-citation-label >}}",
  "{{< meta edition-citation-url >}}",
]) {
  assert.ok(partial.includes(shortcode), `missing shortcode: ${shortcode}`);
}
assert.match(partial, /content-visible when-format="html"/);
assert.match(partial, /content-visible when-format="typst"/);
assert.match(
  partial,
  /Creative Commons Attribution 4\.0 International\s+licence/,
);
assert.match(partial, /Materials linked from Canvas/);

assert.match(wrapper, /^title: "About this handbook"$/m);
assert.match(wrapper, /{{< include _partials\/colophon-content\.qmd >}}/);
for (const shortcode of [
  "{{< meta edition-label >}}",
  "{{< meta edition-semester >}}",
  "{{< meta edition-year >}}",
]) {
  assert.ok(wrapper.includes(shortcode), `missing wrapper shortcode: ${shortcode}`);
}

assert.match(
  quarto,
  /page-footer:\s*\n\s+left:\s*\n\s+- text: About this handbook\s*\n\s+href: about-handbook\.qmd/,
);
const navbarBlock = yamlBlock(quarto, "navbar", 2);
assert.doesNotMatch(
  navbarBlock,
  /about-handbook\.qmd/,
  "About this handbook must remain out of the top navigation",
);
const bookChaptersBlock = yamlBlock(quartoBook, "chapters", 2);
assert.doesNotMatch(
  bookChaptersBlock,
  /about-handbook\.qmd/,
  "About this handbook must remain out of the book chapter list",
);
assert.match(
  unitInformation,
  /\[About this handbook\]\(about-handbook\.qmd\)/,
);
assert.match(homepage, /\[About this handbook\]\(about-handbook\.qmd\)/);
assert.doesNotMatch(homepage, /If resources link back to \[Canvas\]/);

assert.match(homepage, /#beda-colophon\[/);
assert.match(
  homepage,
  /^# About this edition \{#about-this-edition \.unnumbered \.unlisted \.colophon-title\}$/m,
);
assert.match(homepage, /when-format="typst"/);

const typst = read("typst/typst-show.typ");
assert.match(typst, /#let beda-colophon\(body\) = \{/);
assert.match(typst, /footer:\s*none/);
assert.match(typst, /size:\s*9pt,\s*fill:\s*black/);
assert.match(typst, /show heading\.where\(level:\s*1\)/);
assert.match(typst, /show heading\.where\(level:\s*2\)/);
assert.match(typst, /copyright:\s*context/);
assert.match(
  typst,
  /metadata\(\(\s*kind:\s*"beda-colophon",\s*body:\s*\{/,
);
assert.match(
  typst,
  /copyright:\s*context\s*\{[\s\S]*?item\.value\.at\("kind",[\s\S]*?==\s*"beda-colophon"/,
);
assert.match(typst, /colophons\.first\(\)\.value\.body/);

assert.match(readme, /^## Rendering the handbook$/m);
assert.match(readme, /Quarto 1\.9 or later/);
assert.match(readme, /and R before rendering/);
assert.match(readme, /`quarto render`/);
assert.match(readme, /`quarto render --profile book`/);
assert.match(readme, /`_site`/);
assert.match(
  readme,
  /`_book\/Biology-Experimental-Design-and-Analysis\.pdf`/,
);
assert.match(readme, /^## Updating the edition$/m);
assert.match(readme, /`_edition\.yml`/);
assert.match(readme, /Working\s+tags use `vYYYY\.x`/);
assert.match(readme, /final archival tag uses `vYYYY`/);
assert.match(readme, /`edition-citation-url`/);
assert.match(
  readme,
  /render\s+both outputs and run the edition and colophon tests/,
);
for (const command of [
  "node tests/test_edition_metadata.js",
  "node tests/test_colophon_source.js",
  "node tests/test_colophon_rendered.js",
  "node tests/test_colophon_layout.js",
  "node tests/test_colophon_pdf.js",
]) {
  assert.ok(readme.includes(`\`${command}\``), `missing README command: ${command}`);
}

console.log("PASS: colophon shared-source contract");
