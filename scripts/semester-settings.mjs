import fs from "node:fs";
import calendarApi from "./semester-calendar.js";

export const settings = JSON.parse(fs.readFileSync(new URL("../_semester.json", import.meta.url), "utf8"));

export function validateSettings(value) {
  const calendar = value["semester-calendar"];
  if (!Number.isInteger(value["edition-year"]) || ![1, 2].includes(value["edition-semester"])) {
    throw new Error("Set a valid edition year and semester in _semester.json.");
  }
  const periods = [...calendar.teachingWeeks, calendar.midSemesterBreak, calendar.studyVacation, calendar.examinations]
    .sort((a, b) => a.start.localeCompare(b.start));
  if (calendar.teachingWeeks.length !== 13
      || calendar.teachingWeeks.some((period, index) => period.week !== index + 1)
      || calendar.start !== calendar.teachingWeeks[0].start
      || !calendar.start.startsWith(`${value["edition-year"]}-`)
      || calendar.label !== `Semester ${value["edition-semester"]}`) {
    throw new Error("The semester must contain teaching weeks 1–13 and match the edition settings.");
  }
  periods.forEach((period, index) => {
    if (!calendarApi.isDate(period.start) || !calendarApi.isDate(period.end) || period.end < period.start) {
      throw new Error("Every calendar period must have valid, ordered dates.");
    }
    if (index && new Date(`${period.start}T00:00:00Z`) - new Date(`${periods[index - 1].end}T00:00:00Z`) !== 86400000) {
      throw new Error("Calendar periods must be continuous and cannot overlap.");
    }
  });
  const pause = calendar.midSemesterBreak;
  const before = calendar.teachingWeeks.find((period) => period.week === pause.afterWeek);
  if (!calendarApi.isDate(pause.displayEnd) || pause.displayEnd < pause.start || pause.displayEnd > pause.end
      || !before || before.end >= pause.start || calendar.teachingWeeks[pause.afterWeek].start <= pause.end
      || !pause.title) {
    throw new Error("The displayed semester break must fit between its adjacent teaching weeks.");
  }
  for (const name of ["Canvas", "Ed"]) {
    const destination = value.website.navbar.right.find((item) => item.text === name)?.href;
    const expectedHost = name === "Canvas" ? "canvas.sydney.edu.au" : "edstem.org";
    const url = new URL(destination);
    if (url.protocol !== "https:" || url.hostname !== expectedHost || !/\/courses\/\d+\/$/.test(url.pathname)) {
      throw new Error(`Set a valid ${name} course URL.`);
    }
  }
  return value;
}

validateSettings(settings);
export const calendar = settings["semester-calendar"];
export const scheduleKey = `${settings["edition-year"]}-s${settings["edition-semester"]}`;
