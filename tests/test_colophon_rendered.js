#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  edition,
  editionLabel,
  semesterLabel,
} = require("./helpers/edition_metadata.js");

const repoRoot = path.resolve(__dirname, "..");

function read(file) {
  return fs.readFileSync(path.join(repoRoot, file), "utf8");
}

function semanticElement(html, tag, pageName) {
  const match = html.match(
    new RegExp(`<${tag}\\b[^>]*>[\\s\\S]*?<\\/${tag}>`, "i"),
  );
  assert.ok(match, `missing <${tag}> in ${pageName}`);
  return match[0];
}

function decodeEntities(text) {
  return text
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#(\d+);/g, (_, value) =>
      String.fromCodePoint(Number.parseInt(value, 10)),
    )
    .replace(/&#x([\da-f]+);/gi, (_, value) =>
      String.fromCodePoint(Number.parseInt(value, 16)),
    );
}

function textContent(html) {
  return decodeEntities(
    html
      .replace(/<!--[\s\S]*?-->/g, " ")
      .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1>/gi, " ")
      .replace(/<[^>]+>/g, " "),
  )
    .replace(/\s+/g, " ")
    .trim();
}

function headings(html) {
  return [...html.matchAll(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi)].map(
    (match) => ({
      level: Number(match[1]),
      text: textContent(match[2]),
    }),
  );
}

function links(html) {
  return [...html.matchAll(/<a\b[^>]*\bhref=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi)]
    .map((match) => ({
      href: decodeEntities(match[2]),
      text: textContent(match[3]),
    }));
}

function assertLink(linkList, href, text) {
  const normaliseHref = (value) => value.replace(/^\.\//, "");
  assert.ok(
    linkList.some(
      (link) =>
        normaliseHref(link.href) === normaliseHref(href) &&
        link.text.includes(text),
    ),
    `missing link "${text}" to ${href}`,
  );
}

const about = read("_site/about-handbook.html");
const homepage = read("_site/index.html");
const unitInformation = read("_site/unit-information.html");
const aboutMain = semanticElement(about, "main", "About page");
const homepageMain = semanticElement(homepage, "main", "homepage");
const unitInformationMain = semanticElement(
  unitInformation,
  "main",
  "Unit Information page",
);

const documentTitle = about.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i);
assert.ok(documentTitle, "missing About page document title");
assert.ok(
  textContent(documentTitle[1]).includes("About this handbook"),
  "About page document title does not identify the page",
);

const aboutHeadings = headings(aboutMain);
const aboutH1s = aboutHeadings.filter((heading) => heading.level === 1);
assert.equal(aboutH1s.length, 1);
assert.equal(aboutH1s[0].text, "About this handbook");
for (let index = 1; index < aboutHeadings.length; index += 1) {
  assert.ok(
    aboutHeadings[index].level <= aboutHeadings[index - 1].level + 1,
    `heading level skips from h${aboutHeadings[index - 1].level} to h${aboutHeadings[index].level}`,
  );
}

const aboutText = textContent(aboutMain);
for (const phrase of [
  editionLabel,
  semesterLabel,
  "How this book was built",
  "Creative Commons Attribution 4.0 International licence",
  "Suggested citation",
]) {
  assert.ok(aboutText.includes(phrase), `missing rendered phrase: ${phrase}`);
}

const aboutLinks = links(aboutMain);
assert.ok(
  aboutLinks.some(
    (link) => link.href === edition["edition-citation-url"],
  ),
  "missing edition citation URL",
);
assert.ok(
  aboutLinks.some(
    (link) =>
      link.href === "https://creativecommons.org/licenses/by/4.0/",
  ),
  "missing CC BY 4.0 link",
);
assert.ok(
  aboutLinks.some(
    (link) => link.href === "https://github.com/BIOL2022/BEDA-handbook",
  ),
  "missing GitHub repository link",
);
assert.ok(
  aboutLinks.some(
    (link) =>
      link.href ===
      "https://biol2022.github.io/BEDA-handbook/updates.html",
  ),
  "missing handbook updates link",
);

assertLink(
  links(homepageMain),
  "about-handbook.html",
  "About this handbook",
);
assert.match(
  textContent(homepageMain),
  /See About this handbook for the licence scope, exclusions, edition and citation details\./,
);
const homepageFooter = semanticElement(homepage, "footer", "homepage");
assertLink(
  links(homepageFooter),
  "about-handbook.html",
  "About this handbook",
);

assertLink(
  links(unitInformationMain),
  "about-handbook.html",
  "About this handbook",
);
assert.match(
  textContent(unitInformationMain),
  /For publication, edition, licensing and citation details, see About this handbook\s*\./,
);

console.log("PASS: rendered HTML colophon contract");
