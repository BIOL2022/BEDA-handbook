#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const repoRoot = path.resolve(__dirname, "..");
const script = fs.readFileSync(
  path.join(repoRoot, "scripts", "semester-status.js"),
  "utf8"
);

const timelineLabels = [
  "Weeks 2–3",
  "Week 4",
  "Week 5",
  "Week 6",
  "Week 7",
  "Week 8"
];
const timelineDates = [
  "10–23 August",
  "24–30 August",
  "31 August–6 September",
  "7–13 September",
  "14–20 September",
  "21–27 September"
];

function createClassList() {
  const values = new Set();
  return {
    add: (...names) => names.forEach((name) => values.add(name)),
    contains: (name) => values.has(name),
    remove: (...names) => names.forEach((name) => values.delete(name))
  };
}

function createCell(label) {
  const children = [];
  return {
    textContent: String(label),
    append(child) {
      child.remove = () => {
        const index = children.indexOf(child);
        if (index >= 0) children.splice(index, 1);
      };
      children.push(child);
    },
    querySelector(selector) {
      if (!selector.startsWith(".")) return null;
      const className = selector.slice(1);
      return (
        children.find((child) =>
          String(child.className || "")
            .split(/\s+/)
            .includes(className)
        ) || null
      );
    }
  };
}

function createRow(label) {
  const attributes = new Map();
  return {
    cells: [createCell(label)],
    classList: createClassList(),
    getAttribute: (name) => attributes.get(name) || null,
    removeAttribute: (name) => attributes.delete(name),
    setAttribute: (name, value) => attributes.set(name, String(value))
  };
}

function runForDate(isoDate) {
  const rows = Array.from({ length: 13 }, (_, index) => createRow(index + 1));
  const timelineRows = timelineLabels.map((label, index) =>
    createRow(`${label} ${timelineDates[index]}`)
  );
  const status = { textContent: "Loading semester status…" };
  const listeners = new Map();
  const document = {
    readyState: "loading",
    addEventListener(name, callback) {
      listeners.set(name, callback);
    },
    createElement() {
      return { className: "", textContent: "" };
    },
    getElementById(id) {
      return id === "semester-status" ? status : null;
    },
    querySelector() {
      return null;
    },
    querySelectorAll(selector) {
      if (selector === "#weekly-content tbody tr") return rows;
      if (selector === ".module2-timeline-table tbody tr") return timelineRows;
      return [];
    }
  };

  const fixedInstant = isoDate.includes("T") ? isoDate : `${isoDate}T02:00:00Z`;
  class FixedDate extends Date {
    constructor(...arguments_) {
      super(arguments_.length === 0 ? fixedInstant : arguments_[0]);
    }

    static now() {
      return new Date(fixedInstant).valueOf();
    }
  }

  vm.runInNewContext(script, {
    Date: FixedDate,
    Intl,
    console,
    document
  });
  assert.ok(listeners.has("DOMContentLoaded"), "updates should wait for the schedule DOM");
  listeners.get("DOMContentLoaded")();

  return { rows, timelineRows, status };
}

function selectedWeeks(result) {
  return result.rows
    .filter((row) => row.classList.contains("is-current-week"))
    .map((row) => Number(row.cells[0].textContent));
}

function selectedTimelineLabels(result) {
  return result.timelineRows
    .filter((row) => row.classList.contains("is-current-week"))
    .map((row) => {
      const text = row.cells[0].textContent.trim();
      return timelineLabels.find((label) => text.startsWith(label)) || text;
    });
}

function timelineMarkers(result) {
  return result.timelineRows.map((row) =>
    row.cells[0].querySelector(".module2-current-label")
  );
}

const beforeSemester = runForDate("2026-07-20");
assert.deepEqual(selectedWeeks(beforeSemester), [1]);
assert.deepEqual(selectedTimelineLabels(beforeSemester), []);
assert.equal(beforeSemester.rows[0].getAttribute("aria-current"), null);
assert.equal(
  beforeSemester.rows[0].cells[0].querySelector(".current-week-label").textContent,
  "Coming up"
);
assert.equal(beforeSemester.status.textContent, "Semester 2 begins in 2 weeks.");

const weekTwo = runForDate("2026-08-12");
assert.deepEqual(selectedWeeks(weekTwo), [2]);
assert.equal(weekTwo.rows[1].getAttribute("aria-current"), "true");
assert.equal(weekTwo.rows[0].getAttribute("aria-current"), null);
assert.deepEqual(selectedTimelineLabels(weekTwo), ["Weeks 2–3"]);
assert.equal(weekTwo.timelineRows[0].getAttribute("aria-current"), "true");
assert.equal(timelineMarkers(weekTwo)[0].textContent, "You are here");

const weekThree = runForDate("2026-08-19");
assert.deepEqual(selectedTimelineLabels(weekThree), ["Weeks 2–3"]);
assert.equal(weekThree.timelineRows[0].getAttribute("aria-current"), "true");
assert.equal(timelineMarkers(weekThree)[0].textContent, "You are here");

const weekFour = runForDate("2026-08-26");
assert.deepEqual(selectedTimelineLabels(weekFour), ["Week 4"]);
assert.equal(weekFour.timelineRows[1].getAttribute("aria-current"), "true");
assert.equal(timelineMarkers(weekFour)[1].textContent, "You are here");

const weekEight = runForDate("2026-09-25");
assert.deepEqual(selectedTimelineLabels(weekEight), ["Week 8"]);
assert.equal(weekEight.timelineRows[5].getAttribute("aria-current"), "true");
assert.equal(timelineMarkers(weekEight)[5].textContent, "You are here");

const beforeSydneySemesterStart = runForDate("2026-08-02T13:59:59Z");
assert.deepEqual(selectedWeeks(beforeSydneySemesterStart), [1]);
assert.equal(beforeSydneySemesterStart.rows[0].getAttribute("aria-current"), null);

const atSydneySemesterStart = runForDate("2026-08-02T14:00:00Z");
assert.deepEqual(selectedWeeks(atSydneySemesterStart), [1]);
assert.equal(atSydneySemesterStart.rows[0].getAttribute("aria-current"), "true");

const breakPeriod = runForDate("2026-10-01");
assert.deepEqual(selectedWeeks(breakPeriod), []);
assert.deepEqual(selectedTimelineLabels(breakPeriod), []);
assert.equal(breakPeriod.status.textContent, "This is the mid-semester break.");

const afterSemester = runForDate("2026-12-01");
assert.deepEqual(selectedWeeks(afterSemester), []);
assert.deepEqual(selectedTimelineLabels(afterSemester), []);
assert.equal(afterSemester.status.textContent, "Semester 2 has finished.");

for (const result of [beforeSemester, weekTwo, weekThree, weekFour, weekEight, breakPeriod, afterSemester]) {
  assert.ok(
    selectedTimelineLabels(result).length <= 1,
    "at most one Module2 timeline row should be selected"
  );
}

console.log("PASS: semester status and current-week highlighting");
