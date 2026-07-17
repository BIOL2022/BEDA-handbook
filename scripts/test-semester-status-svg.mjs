import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { generate, messageFor, schedules } from "./generate-semester-status-svg.mjs";

const schedule = schedules["2026-s2"];
const cases = [
  ["2026-07-17", "Semester 2 begins in 2 weeks and 3 days"],
  ["2026-08-02", "Semester 2 begins tomorrow"],
  ["2026-08-03", "This is Week 01"],
  ["2026-08-09", "This is Week 01"],
  ["2026-08-10", "This is Week 02"],
  ["2026-09-27", "This is Week 08"],
  ["2026-09-28", "This is the mid-semester break"],
  ["2026-10-05", "This is the mid-semester break"],
  ["2026-10-06", "This is Week 09"],
  ["2026-11-08", "This is Week 13"],
  ["2026-11-09", "This is the study vacation"],
  ["2026-11-16", "This is the examination period"],
  ["2026-11-28", "This is the examination period"],
  ["2026-11-29", "Semester 2 has finished"]
];

for (const [date, expected] of cases) {
  assert.equal(messageFor(schedule, date), expected, date);
}

const directory = fs.mkdtempSync(path.join(os.tmpdir(), "semester-status-"));
const output = path.join(directory, "status.svg");
const narrowOutput = path.join(directory, "status-narrow.svg");
const result = generate({
  date: "2026-07-17",
  year: "2026",
  semester: "2",
  output,
  narrowOutput
});
const svg = fs.readFileSync(output, "utf8");
const narrowSvg = fs.readFileSync(narrowOutput, "utf8");

assert.equal(result.message, cases[0][1]);
assert.match(svg, /fill: #440154/);
assert.match(svg, /font-size: 23px/);
assert.match(svg, /Semester 2 begins in 2 weeks and 3 days/);
assert.match(svg, /<desc[^>]*>Semester 2 begins in 2 weeks and 3 days<\/desc>/);
assert.doesNotMatch(svg, /<script/);
assert.match(narrowSvg, /font-size: 18px/);
assert.match(narrowSvg, /Semester 2 begins in/);
assert.match(narrowSvg, /2 weeks and 3 days/);
assert.doesNotMatch(narrowSvg, /<script/);

console.log(`${cases.length} status boundaries and the generated SVG passed`);
