#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const siteArgument = process.argv[2] || "_site";
const siteRoot = path.resolve(siteArgument);

if (!fs.existsSync(siteRoot) || !fs.statSync(siteRoot).isDirectory()) {
  console.error(`Missing rendered site: ${siteRoot}`);
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
    /^[a-z][a-z\d+.-]*:/i.test(trimmedHref)
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

function isWithinSite(file) {
  const relative = path.relative(siteRoot, file);
  return (
    relative === "" ||
    (!path.isAbsolute(relative) && relative !== ".." && !relative.startsWith(`..${path.sep}`))
  );
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

function firstTable(html) {
  return html.match(/<table\b[^>]*>[\s\S]*?<\/table>/i)?.[0] ?? null;
}

function tableRows(table) {
  return Array.from(table.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi), (rowMatch) => {
    const html = rowMatch[1];
    const cells = Array.from(
      html.matchAll(/<(th|td)\b[^>]*>([\s\S]*?)<\/\1>/gi),
      (cellMatch) => ({
        tag: cellMatch[1].toLowerCase(),
        html: cellMatch[2],
        text: normaliseText(cellMatch[2]),
      }),
    );
    return { html, cells };
  });
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
    if (!isWithinSite(target.file)) {
      failures.push(`${relativeName(file)} links outside rendered site "${link.href}"`);
      continue;
    }
    const targetPage = pages.get(target.file);
    if (!fs.existsSync(target.file)) {
      failures.push(`${relativeName(file)} links to missing file "${link.href}"`);
    } else if (
      target.fragment &&
      path.extname(target.file).toLowerCase() === ".html" &&
      (!targetPage || !targetPage.ids.has(target.fragment))
    ) {
      failures.push(`${relativeName(file)} links to missing fragment "${link.href}"`);
    }
  }
}

const sidebarLabels = [
  "Canvas",
  "Ed",
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
  if (sidebarLinks.some((link) => link.text === "Schedule and weekly content")) {
    failures.push('#quarto-sidebar must not include "Schedule and weekly content"');
  }
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

requireIds("module02/202-timeline.html", ["wk4", "wk5", "wk6", "wk7", "wk8"]);

const indexFile = path.join(siteRoot, "index.html");
const indexPage = pages.get(indexFile);

if (!indexPage) {
  failures.push("missing rendered homepage index.html");
} else {
  if (!indexPage.ids.has("weekly-content")) {
    failures.push('index.html is missing id "weekly-content"');
  }
  if (!indexPage.ids.has("tbl-weekly-content")) {
    failures.push('index.html is missing id "tbl-weekly-content"');
  }

  const weeklySection = indexPage.html.match(
    /<section\b[^>]*\bid=["']weekly-content["'][^>]*>[\s\S]*?<\/section>/i,
  )?.[0];
  const responsiveWrapper = weeklySection
    ? Array.from(weeklySection.matchAll(/<div\b([^>]*)>/gi)).find((match) => {
        const classes = normaliseText(attributeValue(match[1], "class") ?? "").split(" ");
        return (
          classes.includes("table-responsive") &&
          normaliseText(attributeValue(match[1], "tabindex") ?? "") === "0" &&
          normaliseText(attributeValue(match[1], "role") ?? "") === "region" &&
          normaliseText(attributeValue(match[1], "aria-label") ?? "") === "Weekly content table"
        );
      })
    : null;
  const weeklyTable = weeklySection ? firstTable(weeklySection) : null;

  if (!responsiveWrapper) {
    failures.push(
      'index.html#weekly-content is missing its accessible "table-responsive" wrapper',
    );
  }
  if (!weeklyTable) {
    failures.push("index.html#weekly-content is missing its weekly table");
  } else {
    const captionText = normaliseText(
      weeklySection.match(/<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>/i)?.[1] ?? "",
    ).replace(/^Table\s+\d+:\s*/i, "");
    const rows = tableRows(weeklyTable);
    const header = rows.find((row) => row.cells.every((cell) => cell.tag === "th"));
    const bodyRows = rows.filter((row) => row.cells.some((cell) => cell.tag === "td"));
    const headers = header?.cells.map((cell) => cell.text) ?? [];

    if (captionText !== "BEDA weekly content") {
      failures.push(`homepage weekly table has unexpected caption: "${captionText}"`);
    }
    if (JSON.stringify(headers) !== JSON.stringify(["Week", "Lectures", "Practical", "Extras"])) {
      failures.push(`homepage weekly table has unexpected headers: ${headers.join(", ")}`);
    }
    if (bodyRows.length !== 13) {
      failures.push(`homepage weekly table needs 13 rows, found ${bodyRows.length}`);
    }

    const expectedPracticals = [
      ["module01/102-week01.html", null],
      ["module01/103-week02.html", null],
      ["module01/104-week03.html", null],
      ["module02/202-timeline.html", "wk4"],
      ["module02/202-timeline.html", "wk5"],
      ["module02/202-timeline.html", "wk6"],
      ["module02/202-timeline.html", "wk7"],
      ["module02/202-timeline.html", "wk8"],
      ["module03/302-week09.html", null],
      ["module03/303-week10.html", null],
      ["module03/304-week11.html", null],
      ["module03/305-week12.html", null],
    ];
    const expectedDates = [
      "3–7 August",
      "10–14 August",
      "17–21 August",
      "24–28 August",
      "31 August–4 September",
      "7–11 September",
      "14–18 September",
      "21–25 September",
      "5–9 October",
      "12–16 October",
      "19–23 October",
      "26–30 October",
      "2–6 November",
    ];

    for (let index = 0; index < bodyRows.length; index += 1) {
      const row = bodyRows[index];
      const week = index + 1;
      const weekText = row.cells[0]?.text ?? "";
      if (row.cells.length !== 4) {
        failures.push(`homepage weekly table row ${week} needs 4 cells, found ${row.cells.length}`);
      }
      if (!new RegExp(`^${week}\\b`).test(weekText)) {
        failures.push(`homepage weekly table row ${week} is out of order`);
      }
      if (expectedDates[index] && !weekText.includes(expectedDates[index])) {
        failures.push(`homepage Week ${week} is missing date "${expectedDates[index]}"`);
      }
    }

    for (let index = 0; index < expectedPracticals.length; index += 1) {
      const row = bodyRows[index];
      if (!row || !row.cells[2]) continue;
      const [expectedFile, expectedFragment] = expectedPracticals[index];
      const practicalLinks = extract(row.cells[2].html).links;
      const found = practicalLinks.some((link) => {
        const target = resolveInternal(indexFile, link.href);
        return target &&
          relativeName(target.file) === expectedFile &&
          (target.fragment ?? null) === expectedFragment;
      });
      if (!found) {
        failures.push(`homepage Week ${index + 1} is missing practical destination ${expectedFile}`);
      }
    }

    const week6 = bodyRows[5];
    if (week6 && !/no practical this week/i.test(week6.cells[2]?.text ?? "")) {
      failures.push('homepage Week 6 must state "No practical this week"');
    }

    const week13 = bodyRows[12];
    if (week13) {
      if (!/exam revision and questions/i.test(week13.cells[1]?.text ?? "")) {
        failures.push("homepage Week 13 is missing exam revision and questions");
      }
      if (!/feedback and discussion practical/i.test(week13.cells[2]?.text ?? "")) {
        failures.push("homepage Week 13 is missing the feedback and discussion practical");
      }
      if (extract(week13.cells[2]?.html ?? "").links.length > 0) {
        failures.push("homepage Week 13 practical must remain plain text");
      }
      if (!/report 2/i.test(week13.cells[3]?.text ?? "")) {
        failures.push("homepage Week 13 Extras must include the Report 2 reminder");
      }
    }
  }
}

if (pages.has(path.join(siteRoot, "schedule.html"))) {
  failures.push("rendered site must not contain schedule.html");
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
      return target && target.file === childFile;
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
