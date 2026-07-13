#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const siteArgument = process.argv[2] || "_site";
const siteRoot = path.resolve(siteArgument);

if (!fs.existsSync(siteRoot) || !fs.statSync(siteRoot).isDirectory()) {
  console.error("Missing rendered site");
  process.exit(1);
}

function collectHtmlFiles(directory) {
  const files = [];

  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectHtmlFiles(entryPath));
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".html")) {
      files.push(entryPath);
    }
  }

  return files.sort();
}

function decodeEntities(value) {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&apos;|&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#(\d+);/g, (_, number) => String.fromCodePoint(Number(number)))
    .replace(/&#x([\da-f]+);/gi, (_, number) =>
      String.fromCodePoint(Number.parseInt(number, 16)),
    );
}

function normaliseText(value) {
  return decodeEntities(value.replace(/<[^>]*>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function attributeValue(attributes, name) {
  const match = attributes.match(
    new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, "i"),
  );
  return match ? decodeEntities(match[1] ?? match[2] ?? match[3] ?? "") : null;
}

function extract(html) {
  const ids = [];
  const links = [];
  const tagPattern = /<[a-z][^<>]*>/gi;
  const anchorPattern = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;

  for (const match of html.matchAll(tagPattern)) {
    const id = attributeValue(match[0], "id");
    if (id !== null) {
      ids.push(id);
    }
  }

  for (const match of html.matchAll(anchorPattern)) {
    const href = attributeValue(match[1], "href");
    if (href !== null) {
      links.push({ href, text: normaliseText(match[2]) });
    }
  }

  return { ids, links };
}

function safeDecode(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function resolveInternal(fromFile, href) {
  const trimmedHref = href.trim();
  if (
    !trimmedHref ||
    trimmedHref.startsWith("//") ||
    /^(?:https?:|mailto:|tel:|javascript:|data:)/i.test(trimmedHref)
  ) {
    return null;
  }

  const hashIndex = trimmedHref.indexOf("#");
  const rawPath = hashIndex === -1 ? trimmedHref : trimmedHref.slice(0, hashIndex);
  const rawFragment = hashIndex === -1 ? null : trimmedHref.slice(hashIndex + 1);
  const pathWithoutQuery = rawPath.split("?", 1)[0];
  const isSiteRootPath =
    pathWithoutQuery === "/BEDA-handbook" || pathWithoutQuery.startsWith("/BEDA-handbook/");
  let targetPath = safeDecode(pathWithoutQuery);

  if (targetPath.startsWith("/BEDA-handbook/")) {
    targetPath = targetPath.slice("/BEDA-handbook/".length);
  } else if (targetPath === "/BEDA-handbook") {
    targetPath = "";
  }

  let absoluteTarget;
  if (!targetPath) {
    absoluteTarget = isSiteRootPath ? path.join(siteRoot, "index.html") : fromFile;
  } else if (targetPath.startsWith("/")) {
    absoluteTarget = path.join(siteRoot, targetPath.replace(/^\/+/, ""));
  } else {
    absoluteTarget = path.resolve(path.dirname(fromFile), targetPath);
  }

  if (targetPath.endsWith("/")) {
    absoluteTarget = path.join(absoluteTarget, "index.html");
  } else if (!path.extname(absoluteTarget)) {
    absoluteTarget = path.join(absoluteTarget, "index.html");
  }

  return {
    file: path.normalize(absoluteTarget),
    fragment: rawFragment === null || rawFragment === "" ? null : safeDecode(rawFragment),
  };
}

function relativeName(file) {
  return path.relative(siteRoot, file).split(path.sep).join("/");
}

function sidebarHtml(html) {
  const opening = html.match(/<(nav|aside|div)\b[^>]*\bid\s*=\s*["']quarto-sidebar["'][^>]*>/i);
  if (!opening || opening.index === undefined) {
    return null;
  }

  const closingTag = `</${opening[1].toLowerCase()}>`;
  const closingIndex = html.toLowerCase().indexOf(closingTag, opening.index + opening[0].length);
  return closingIndex === -1
    ? html.slice(opening.index)
    : html.slice(opening.index, closingIndex + closingTag.length);
}

const failures = [];
const htmlFiles = collectHtmlFiles(siteRoot);
const pages = new Map();

for (const file of htmlFiles) {
  const html = fs.readFileSync(file, "utf8");
  const extracted = extract(html);
  pages.set(path.normalize(file), { html, ids: new Set(extracted.ids), links: extracted.links });

  const counts = new Map();
  for (const id of extracted.ids) {
    counts.set(id, (counts.get(id) || 0) + 1);
  }
  for (const [id, count] of counts) {
    if (id && count > 1) {
      failures.push(`${relativeName(file)} has duplicate id "${id}" (${count} occurrences)`);
    }
  }
}

for (const [file, page] of pages) {
  for (const link of page.links) {
    const target = resolveInternal(file, link.href);
    if (!target) {
      continue;
    }
    const targetPage = pages.get(target.file);
    if (!fs.existsSync(target.file)) {
      failures.push(`${relativeName(file)} links to missing file "${link.href}"`);
    } else if (target.fragment && (!targetPage || !targetPage.ids.has(target.fragment))) {
      failures.push(`${relativeName(file)} links to missing fragment "${link.href}"`);
    }
  }
}

const sidebarLabels = [
  "Canvas",
  "Ed",
  "Schedule and weekly content",
  "Assessments",
  "Unit information",
  "Contact",
  "Cheatsheets",
];
const sidebarPage = pages.get(path.join(siteRoot, "index.html")) || pages.values().next().value;
const sidebar = sidebarPage ? sidebarHtml(sidebarPage.html) : null;

if (!sidebar) {
  failures.push("rendered site is missing #quarto-sidebar");
} else {
  const sidebarLinks = extract(sidebar).links;
  for (const label of sidebarLabels) {
    if (!sidebarLinks.some((link) => link.text === label)) {
      failures.push(`#quarto-sidebar is missing visible label "${label}"`);
    }
  }

  const hasHomeLink = sidebarLinks.some((link) => {
    if (link.text !== "BIOL2022" && link.text !== "Home") {
      return false;
    }
    const target = resolveInternal(path.join(siteRoot, "index.html"), link.href);
    return target && target.file === path.join(siteRoot, "index.html");
  });
  if (!hasHomeLink) {
    failures.push('#quarto-sidebar needs a "BIOL2022" or explicit "Home" link to index.html');
  }
}

function requireIds(relativeFile, requiredIds) {
  const file = path.join(siteRoot, ...relativeFile.split("/"));
  const page = pages.get(file);
  if (!page) {
    failures.push(`missing rendered page ${relativeFile}`);
    return;
  }
  for (const id of requiredIds) {
    if (!page.ids.has(id)) {
      failures.push(`${relativeFile} is missing id "${id}"`);
    }
  }
}

requireIds("schedule.html", [
  "week-index",
  ...Array.from({ length: 13 }, (_, index) => `wk${String(index + 1).padStart(2, "0")}`),
]);
requireIds("module02/202-timeline.html", ["wk4", "wk5", "wk6", "wk7", "wk8"]);

const schedulePage = pages.get(path.join(siteRoot, "schedule.html"));
if (schedulePage) {
  const hasJumpLabel = Array.from(schedulePage.html.matchAll(/<[^>]+\baria-label\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*>/gi)).some(
    (match) => normaliseText(match[1] ?? match[2] ?? "").toLowerCase() === "jump to week",
  );
  if (!hasJumpLabel) {
    failures.push('schedule.html is missing aria-label "Jump to week"');
  }

  for (const link of schedulePage.links) {
    if (/^(?:here|pdf|check timeline)$/i.test(link.text)) {
      failures.push(`schedule.html uses generic anchor text "${link.text}" for "${link.href}"`);
    }
  }
}

const contextualRoutes = new Map([
  ["prerequisites.html", ["index.html", "unit-information.html"]],
  ["module01/101-intro.html", ["module01/102-week01.html"]],
  ["module01/w01-intro.html", ["module01/102-week01.html"]],
  ["module01/w02-tidy-data.html", ["module01/103-week02.html"]],
  ["module01/105-images.html", ["module01/103-week02.html"]],
  ["module01/106-species-id.html", ["module01/103-week02.html"]],
  ["module01/w03-model-fitting-assumptions.html", ["module01/104-week03.html"]],
  ["module02/201-intro.html", ["module02/202-timeline.html"]],
  ["module02/205-resources.html", ["module02/202-timeline.html"]],
  ["module02/203-projects.html", ["assessments/assessments.html", "module02/202-timeline.html"]],
  ["module02/204-report1.html", ["assessments/assessments.html", "module02/202-timeline.html"]],
  ["module02/206-rubric.html", ["assessments/assessments.html"]],
  ["module03/301-intro.html", ["module03/302-week09.html"]],
]);

for (const [childName, parentNames] of contextualRoutes) {
  const childFile = path.join(siteRoot, ...childName.split("/"));
  if (!pages.has(childFile)) {
    failures.push(`missing rendered contextual target ${childName}`);
    continue;
  }

  for (const parentName of parentNames) {
    const parentFile = path.join(siteRoot, ...parentName.split("/"));
    const parentPage = pages.get(parentFile);
    if (!parentPage) {
      failures.push(`missing rendered contextual parent ${parentName}`);
      continue;
    }
    const hasRoute = parentPage.links.some((link) => {
      const target = resolveInternal(parentFile, link.href);
      return target && path.basename(target.file) === path.basename(childFile);
    });
    if (!hasRoute) {
      failures.push(`${parentName} is missing a contextual link to ${childName}`);
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`FAIL: ${failure}`);
  }
  process.exit(1);
}

console.log(
  `PASS: ${htmlFiles.length} HTML files checked; sidebar, fragments, and contextual routes are valid`,
);
