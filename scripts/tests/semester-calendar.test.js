const test = require("node:test");
const assert = require("node:assert/strict");
const { isDate, sydneyDate, periodFor, messageFor } = require("../semester-calendar.js");
const settings = require("../../_semester.json");
const calendar = require("./fixtures/semester-calendar-2026.json");

test("calendar messages preserve semester boundary dates", () => {
  const expected = {
    "2026-08-02": "Semester 2 begins tomorrow",
    "2026-08-03": "This is Week 01",
    "2026-09-27": "This is Week 08",
    "2026-09-28": "This is the mid-semester break",
    "2026-10-02": "This is the mid-semester break",
    "2026-10-05": "This is the mid-semester break",
    "2026-10-06": "This is Week 09",
    "2026-11-08": "This is Week 13",
    "2026-11-09": "This is the study vacation",
    "2026-11-16": "This is the examination period",
    "2026-11-28": "This is the examination period",
    "2026-11-29": "Semester 2 has finished"
  };
  for (const [date, message] of Object.entries(expected)) assert.equal(messageFor(calendar, date), message);
  assert.equal(periodFor(calendar, "2026-10-05").week, undefined);
  assert.equal(periodFor(calendar, "2026-10-06").week, 9);
});

test("status uses Sydney's date across midnight and daylight saving", () => {
  assert.equal(sydneyDate(new Date("2026-10-05T12:59:00Z")), "2026-10-05");
  assert.equal(sydneyDate(new Date("2026-10-05T13:00:00Z")), "2026-10-06");
});

test("preview dates reject impossible dates", () => {
  assert.equal(isDate("2026-02-30"), false);
  assert.equal(isDate("2028-02-29"), true);
  assert.equal(isDate("2026-13-01"), false);
  assert.equal(isDate(null), false);
});

test("invalid semester calendars fail before generating output", async () => {
  const { validateSettings } = await import("../semester-settings.mjs");
  const overlap = structuredClone(settings);
  overlap["semester-calendar"].teachingWeeks[8].start = overlap["semester-calendar"].midSemesterBreak.end;
  assert.throws(() => validateSettings(overlap), /overlap/);
  const wrongYear = structuredClone(settings);
  wrongYear["edition-year"] += 1;
  assert.throws(() => validateSettings(wrongYear), /match the edition/);
});

test("SVG generation uses the shared semester messages", async () => {
  const { schedules, messageFor: svgMessageFor } = await import("../generate-semester-status-svg.mjs");
  const liveCalendar = settings["semester-calendar"];
  const key = `${settings["edition-year"]}-s${settings["edition-semester"]}`;
  assert.equal(svgMessageFor(schedules[key], liveCalendar.start), "This is Week 01");
});
