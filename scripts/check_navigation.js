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
  const idElements = new Map();
  const links = [];
  const tagPattern = /<[a-z][^<>]*>/gi;
  const anchorPattern = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi;

  for (const match of html.matchAll(tagPattern)) {
    const id = attributeValue(match[0], "id");
    if (id !== null) {
      ids.push(id);
      const elements = idElements.get(id) || [];
      elements.push(match[0]);
      idElements.set(id, elements);
    }
  }

  for (const match of html.matchAll(anchorPattern)) {
    const href = attributeValue(match[1], "href");
    if (href !== null) {
      links.push({ href, text: normaliseText(match[2]) });
    }
  }

  return { ids, idElements, links };
}

function isQuartoThemeStylesheetGroup(id, elements) {
  if (!["quarto-bootstrap", "quarto-text-highlighting-styles"].includes(id)) {
    return false;
  }

  // Quarto deliberately repeats these IDs for its primary, alternate and
  // initial-paint stylesheets. Do not exempt content elements using those IDs.
  const roles = elements.map((element) => {
    if (!/^<link\b/i.test(element)) return null;
    const classes = (attributeValue(element, "class") || "").split(/\s+/);
    const rel = attributeValue(element, "rel");
    const href = attributeValue(element, "href") || "";
    const expectedAsset = id === "quarto-bootstrap"
      ? /(?:^|\/)site_libs\/bootstrap\/bootstrap(?:-dark)?(?:-[\w]+)?\.min\.css(?:\?.*)?$/
      : /(?:^|\/)site_libs\/quarto-html\/quarto-syntax-highlighting(?:-dark)?(?:-[\w]+)?\.css(?:\?.*)?$/;
    if (!["stylesheet", "disabled-stylesheet"].includes(rel) || !expectedAsset.test(href)) {
      return null;
    }
    if (classes.includes("quarto-color-scheme-extra")) return "extra";
    if (!classes.includes("quarto-color-scheme")) return null;
    return classes.includes("quarto-color-alternate") ? "alternate" : "primary";
  });

  return roles.includes("primary") && roles.includes("alternate") &&
    roles.every(Boolean) && new Set(roles).size === roles.length;
}

function safeDecode(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function resolveInternal(fromFile, href) {
  let trimmedHref = href.trim();
  if (/^https?:\/\//i.test(trimmedHref)) {
    let url;
    try {
      url = new URL(trimmedHref);
    } catch {
      return null;
    }
    if (
      url.hostname !== "biol2022.github.io" ||
      !(url.pathname === "/BEDA-handbook" || url.pathname.startsWith("/BEDA-handbook/"))
    ) {
      return null;
    }
    trimmedHref = `${url.pathname}${url.search}${url.hash}`;
  }
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
  } else if (isSiteRootPath) {
    absoluteTarget = path.join(siteRoot, targetPath);
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
    if (id && count > 1 && !isQuartoThemeStylesheetGroup(id, extracted.idElements.get(id))) {
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
  "About",
  "Updates",
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

function hasClass(attributes, name) {
  return (attributeValue(attributes, "class") || "").split(/\s+/).includes(name);
}

function checkWeeklySchedule(relativeFile) {
  const file = path.join(siteRoot, relativeFile);
  const page = pages.get(file);
  if (!page) {
    failures.push(`missing rendered schedule page ${relativeFile}`);
    return;
  }

  const sectionStart = page.html.match(
    /<div\b([^>]*\bid=["']weekly-content["'][^>]*)>/i,
  );
  if (!sectionStart) {
    failures.push(`${relativeFile} is missing #weekly-content`);
    return;
  }
  if (
    attributeValue(sectionStart[1], "role") !== "region" ||
    attributeValue(sectionStart[1], "aria-label") !== "Weekly content schedule"
  ) {
    failures.push(`${relativeFile}#weekly-content needs a named schedule region`);
  }

  const weeklySection = page.html.slice(sectionStart.index);
  const wrapper = Array.from(weeklySection.matchAll(/<div\b([^>]*)>/gi)).find(
    (match) => hasClass(match[1], "weekly-schedule-desktop") && hasClass(match[1], "table-responsive"),
  );
  if (!wrapper || attributeValue(wrapper[1], "tabindex") !== "0") {
    failures.push(`${relativeFile} is missing its keyboard-accessible desktop schedule wrapper`);
  }

  const weeklyTable = firstTable(weeklySection);
  const weeklyRows = [];
  if (!weeklyTable) {
    failures.push(`${relativeFile}#weekly-content is missing its weekly table`);
  } else {
    const rows = tableRows(weeklyTable);
    const header = rows.find((row) => row.cells.every((cell) => cell.tag === "th"));
    const bodyRows = rows.filter((row) => row.cells.some((cell) => cell.tag === "td"));
    weeklyRows.push(...bodyRows.filter((row) => /^\d+$/.test(row.cells[0]?.text ?? "")));
    const breakRows = bodyRows.filter((row) => (row.cells[0]?.text ?? "") === "Break");
    const headers = header?.cells.map((cell) => cell.text) ?? [];

    if (/<caption\b/i.test(weeklyTable)) {
      failures.push(`${relativeFile} weekly table should not have a caption`);
    }
    if (JSON.stringify(headers) !== JSON.stringify(["Week", "Resources", "Notes"])) {
      failures.push(`${relativeFile} weekly table has unexpected headers: ${headers.join(", ")}`);
    }
    if (weeklyRows.length !== 13) {
      failures.push(`${relativeFile} weekly table needs 13 teaching-week rows, found ${weeklyRows.length}`);
    }
    if (breakRows.length !== 1) {
      failures.push(`${relativeFile} weekly table needs 1 semester-break row, found ${breakRows.length}`);
    }

    for (let index = 0; index < weeklyRows.length; index += 1) {
      const row = weeklyRows[index];
      const week = index + 1;
      if (row.cells.length !== 3) {
        failures.push(`${relativeFile} weekly table row ${week} needs 3 cells, found ${row.cells.length}`);
      }
      if (row.cells[0]?.text !== String(week) || row.cells[0]?.tag !== "th") {
        failures.push(`${relativeFile} weekly table row ${week} needs its ordered week header`);
      }
      const resourceLinks = extract(row.cells[1]?.html ?? "").links;
      const expectedLecture = `lectures/L${String(week).padStart(2, "0")}/index.html`;
      const hasLectureHub = resourceLinks.some((link) => {
        const target = resolveInternal(file, link.href);
        return target && relativeName(target.file) === expectedLecture;
      });
      // Week 13 is an unpublished revision hub, deliberately unlinked here.
      if (week <= 12 && !hasLectureHub) {
        failures.push(`${relativeFile} Week ${week} is missing lecture hub ${expectedLecture}`);
      }
    }

    for (const row of breakRows) {
      if (row.cells.length !== 3) {
        failures.push(`${relativeFile} semester-break row needs 3 cells, found ${row.cells.length}`);
      }
      if (!normaliseText(row.cells[1]?.html ?? "").startsWith("Mid-semester break")) {
        failures.push(`${relativeFile} semester-break row is missing its title and dates`);
      }
      if (normaliseText(row.cells[2]?.html ?? "")) {
        failures.push(`${relativeFile} semester-break row should leave Notes blank`);
      }
    }
  }

  const mobileWrapper = Array.from(weeklySection.matchAll(/<div\b([^>]*)>/gi)).find(
    (match) => hasClass(match[1], "weekly-schedule-mobile"),
  );
  if (!mobileWrapper) {
    failures.push(`${relativeFile} is missing its mobile schedule wrapper`);
  }
  const mobileSections = Array.from(
    weeklySection.matchAll(/<section\b([^>]*)>([\s\S]*?)<\/section>/gi),
  );
  const mobileWeeks = mobileSections.filter((match) => hasClass(match[1], "weekly-mobile-week"));
  if (mobileWeeks.length !== 13) {
    failures.push(`${relativeFile} mobile schedule needs 13 teaching weeks, found ${mobileWeeks.length}`);
  }
  const mobileBreaks = mobileSections.filter((match) => hasClass(match[1], "weekly-mobile-break"));
  if (mobileBreaks.length !== 1 || !normaliseText(mobileBreaks[0]?.[2] || "").includes("Mid-semester break")) {
    failures.push(`${relativeFile} mobile schedule needs its semester-break entry`);
  }
  const jumpLink = Array.from(weeklySection.matchAll(/<a\b([^>]*)>/gi)).find(
    (match) => hasClass(match[1], "weekly-current-week-jump"),
  );
  if (!jumpLink) {
    failures.push(`${relativeFile} mobile schedule is missing its current-week jump link`);
  }

  function linkDestinations(html) {
    return Array.from(new Set(extract(html).links.map((link) => {
      const target = resolveInternal(file, link.href);
      return target ? `${relativeName(target.file)}#${target.fragment || ""}` : link.href;
    }))).sort();
  }

  for (let index = 0; index < mobileWeeks.length; index += 1) {
    const [_, attributes, content] = mobileWeeks[index];
    const week = index + 1;
    const headingId = `mobile-week-${week}-title`;
    if (
      attributeValue(attributes, "id") !== `mobile-week-${week}` ||
      attributeValue(attributes, "data-schedule-week") !== String(week) ||
      attributeValue(attributes, "aria-labelledby") !== headingId ||
      !extract(content).ids.includes(headingId)
    ) {
      failures.push(`${relativeFile} mobile Week ${week} needs its ordered, labelled section`);
    }
    const desktopRow = weeklyRows[index];
    if (desktopRow && JSON.stringify(linkDestinations(content)) !== JSON.stringify(linkDestinations(desktopRow.html))) {
      failures.push(`${relativeFile} mobile Week ${week} links differ from the desktop schedule`);
    }
  }
}

checkWeeklySchedule("index.html");
checkWeeklySchedule("schedule.html");

const timeline = pages.get(path.join(siteRoot, "module02/202-timeline.html"));
const timelineWrapper = timeline && Array.from(timeline.html.matchAll(/<div\b([^>]*)>/gi)).find(
  (match) => hasClass(match[1], "module2-timeline-table"),
);
if (
  !timelineWrapper ||
  attributeValue(timelineWrapper[1], "role") !== "region" ||
  attributeValue(timelineWrapper[1], "aria-label") !== "Module 2 timeline" ||
  attributeValue(timelineWrapper[1], "tabindex") !== "0"
) {
  failures.push("Module 2 timeline needs its named, keyboard-accessible table wrapper");
} else {
  const table = firstTable(timeline.html.slice(timelineWrapper.index));
  const rows = table ? tableRows(table) : [];
  const headers = rows[0]?.cells.map((cell) => cell.text) || [];
  const expectedHeaders = ["Week", "In your timetabled session", "Between practical sessions and in your own time"];
  if (JSON.stringify(headers) !== JSON.stringify(expectedHeaders)) {
    failures.push(`Module 2 timeline has unexpected headers: ${headers.join(", ")}`);
  }
  const labels = ["Weeks 2–3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8"];
  if (rows.length !== labels.length + 1 || labels.some((label, index) =>
    rows[index + 1]?.cells.length !== 3 || !rows[index + 1]?.cells[0]?.text.startsWith(label)
  )) {
    failures.push("Module 2 timeline needs its six ordered periods from Weeks 2–3 through Week 8");
  }
}

const contextualRoutes = new Map([
  ["prerequisites.html", ["index.html", "unit-information.html"]],
  ["module01/105-images.html", ["module01/103-week02.html"]],
  ["module01/106-species-id.html", ["module01/103-week02.html"]],
  ["module01/w03-model-fitting-assumptions.html", ["module01/104-week03.html"]],
  ["module02/200-welcome.html", ["index.html", "module02/202-timeline.html"]],
  ["module02/201-overview.html", ["module02/202-timeline.html"]],
  ["module02/205-resources.html", ["module02/202-timeline.html"]],
  ["module02/203-projects.html", ["index.html", "module02/202-timeline.html"]],
  ["module02/204-report1.html", ["module02/202-timeline.html"]],
  ["module02/206-rubric.html", ["module02/202-timeline.html"]],
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
