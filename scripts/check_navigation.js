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

function navbarHtml(html) {
  const opening = html.match(/<header\b[^>]*\bid\s*=\s*["']quarto-header["'][^>]*>/i);
  if (!opening || opening.index === undefined) {
    return null;
  }

  const closingTag = "</header>";
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

const navbarLabels = [
  "Home",
  "Canvas",
  "Ed",
  "Assessments",
  "Unit information",
  "Contact",
  "Cheatsheets",
];
const navbarPage = pages.get(path.join(siteRoot, "index.html")) || pages.values().next().value;
const navbar = navbarPage ? navbarHtml(navbarPage.html) : null;

if (!navbar) {
  failures.push("rendered site is missing #quarto-header");
} else {
  const navbarLinks = extract(navbar).links;
  if (navbarLinks.some((link) => link.text === "Schedule and weekly content")) {
    failures.push('#quarto-header must not include "Schedule and weekly content"');
  }
  for (const label of navbarLabels) {
    if (!navbarLinks.some((link) => link.text === label)) {
      failures.push(`#quarto-header is missing visible label "${label}"`);
    }
  }

  const hasHomeLink = navbarLinks.some((link) => {
    if (link.text !== "BIOL2022" && link.text !== "Home") {
      return false;
    }
    const target = resolveInternal(path.join(siteRoot, "index.html"), link.href);
    return target && target.file === path.join(siteRoot, "index.html");
  });
  if (!hasHomeLink) {
    failures.push('#quarto-header needs an explicit "Home" link to index.html');
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
  const weeklySectionStart = indexPage.html.match(
    /<div\b[^>]*\bid=["']weekly-content["'][^>]*>/i,
  );
  const weeklySection = weeklySectionStart
    ? indexPage.html.slice(weeklySectionStart.index)
    : null;
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
    const caption = weeklySection.match(/<figcaption\b[^>]*>[\s\S]*?<\/figcaption>/i);
    const rows = tableRows(weeklyTable);
    const header = rows.find((row) => row.cells.every((cell) => cell.tag === "th"));
    const bodyRows = rows.filter((row) => row.cells.some((cell) => cell.tag === "td"));
    const weeklyRows = bodyRows.filter((row) => /^\d+$/.test(row.cells[0]?.text ?? ""));
    const breakRows = bodyRows.filter((row) => (row.cells[0]?.text ?? "") === "Break");
    const headers = header?.cells.map((cell) => cell.text) ?? [];

    if (caption) {
      failures.push("homepage weekly table should not have a caption");
    }
    if (
      JSON.stringify(headers) !==
      JSON.stringify(["Week", "Lectures", "Practical", "Notes"])
    ) {
      failures.push(`homepage weekly table has unexpected headers: ${headers.join(", ")}`);
    }
    if (weeklyRows.length !== 13) {
      failures.push(`homepage weekly table needs 13 teaching-week rows, found ${weeklyRows.length}`);
    }
    if (breakRows.length !== 1) {
      failures.push(`homepage weekly table needs 1 semester-break row, found ${breakRows.length}`);
    }

    for (let index = 0; index < weeklyRows.length; index += 1) {
      const row = weeklyRows[index];
      const week = index + 1;
      const weekText = row.cells[0]?.text ?? "";
      if (row.cells.length !== 4) {
        failures.push(`homepage weekly table row ${week} needs 4 cells, found ${row.cells.length}`);
      }
      if (weekText !== String(week)) {
        failures.push(`homepage weekly table row ${week} is out of order`);
      }

      const lectureLinks = extract(row.cells[1]?.html ?? "").links;
      const expectedLecture = `lectures/L${String(week).padStart(2, "0")}/index.html`;
      const hasLectureHub = lectureLinks.some((link) => {
        const target = resolveInternal(indexFile, link.href);
        return target && relativeName(target.file) === expectedLecture;
      });
      if (!hasLectureHub) {
        failures.push(`homepage Week ${week} is missing lecture hub ${expectedLecture}`);
      }

      const practicalHtml = row.cells[2]?.html ?? "";
      const practicalLinks = extract(practicalHtml).links;
      const practicalText = normaliseText(practicalHtml);
      const hasPracticalLabel = /^(?:Week \d+ )?Practical session(?:, including Workshop \d+)?$/i.test(
        practicalText,
      );
      const hasEmptyMarker = practicalText === "—";
      if (!hasPracticalLabel && !hasEmptyMarker) {
        failures.push(`homepage Week ${week} has an unexpected Practical cell`);
      }
      if (
        week === 1 &&
        practicalText !== "Week 1 practical session"
      ) {
        failures.push(
          "homepage Week 1 practical icon does not describe the combined session",
        );
      }
      if (practicalLinks.length > 1) {
        failures.push(`homepage Week ${week} has more than one practical link`);
      }
    }

    for (const row of breakRows) {
      if (row.cells.length !== 4) {
        failures.push(`homepage semester-break row needs 4 cells, found ${row.cells.length}`);
      }
      if (!normaliseText(row.cells[1]?.html ?? "").startsWith("Mid-semester break")) {
        failures.push("homepage semester-break row is missing its title and dates");
      }
      if (normaliseText(row.cells[2]?.html ?? "") || normaliseText(row.cells[3]?.html ?? "")) {
        failures.push("homepage semester-break row should leave Practical and Notes blank");
      }
    }

    if (normaliseText(weeklyTable).includes("Software and graphical models")) {
      failures.push("homepage weekly table should hide the Week 1 workshop row");
    }
  }
}

const scheduleFile = path.join(siteRoot, "schedule.html");
if (!pages.has(scheduleFile)) {
  failures.push("rendered site is missing the direct-link schedule.html page");
}

const contextualRoutes = new Map([
  ["prerequisites.html", ["index.html", "unit-information.html"]],
  ["module01/101-intro.html", ["module01/102-week01.html"]],
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
  `PASS: ${htmlFiles.length} HTML files checked; navbar, fragments, and contextual routes are valid`,
);
