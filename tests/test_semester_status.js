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

function createClassList() {
  const values = new Set();
  return {
    add: (...names) => names.forEach((name) => values.add(name)),
    contains: (name) => values.has(name),
    remove: (...names) => names.forEach((name) => values.delete(name))
  };
}

function createCell(week) {
  const children = [];
  return {
    textContent: String(week),
    append(child) {
      child.remove = () => {
        const index = children.indexOf(child);
        if (index >= 0) children.splice(index, 1);
      };
      children.push(child);
    },
    querySelector(selector) {
      if (selector !== ".current-week-label") return null;
      return children.find((child) => child.className === "current-week-label") || null;
    }
  };
}

function createRow(week) {
  const attributes = new Map();
  return {
    cells: [createCell(week)],
    classList: createClassList(),
    getAttribute: (name) => attributes.get(name) || null,
    removeAttribute: (name) => attributes.delete(name),
    setAttribute: (name, value) => attributes.set(name, String(value))
  };
}

function runForDate(isoDate) {
  const rows = Array.from({ length: 13 }, (_, index) => createRow(index + 1));
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
    querySelectorAll(selector) {
      return selector === "#weekly-content tbody tr" ? rows : [];
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

  return { rows, status };
}

function selectedWeeks(result) {
  return result.rows
    .filter((row) => row.classList.contains("is-current-week"))
    .map((row) => Number(row.cells[0].textContent));
}

const beforeSemester = runForDate("2026-07-20");
assert.deepEqual(selectedWeeks(beforeSemester), [1]);
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

const beforeSydneySemesterStart = runForDate("2026-08-02T13:59:59Z");
assert.deepEqual(selectedWeeks(beforeSydneySemesterStart), [1]);
assert.equal(beforeSydneySemesterStart.rows[0].getAttribute("aria-current"), null);

const atSydneySemesterStart = runForDate("2026-08-02T14:00:00Z");
assert.deepEqual(selectedWeeks(atSydneySemesterStart), [1]);
assert.equal(atSydneySemesterStart.rows[0].getAttribute("aria-current"), "true");

const breakPeriod = runForDate("2026-10-01");
assert.deepEqual(selectedWeeks(breakPeriod), []);
assert.equal(breakPeriod.status.textContent, "This is the mid-semester break.");

const afterSemester = runForDate("2026-12-01");
assert.deepEqual(selectedWeeks(afterSemester), []);
assert.equal(afterSemester.status.textContent, "Semester 2 has finished.");

console.log("PASS: semester status and current-week highlighting");
