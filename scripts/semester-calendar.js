// Shared by browser status widgets and the SVG generator.
((root) => {
  "use strict";

  function utcDay(date) {
    const [year, month, day] = date.split("-").map(Number);
    return Date.UTC(year, month - 1, day);
  }

  function isDate(date) {
    return typeof date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(date)
      && new Date(utcDay(date)).toISOString().slice(0, 10) === date;
  }

  function sydneyDate(now = new Date()) {
    const parts = new Intl.DateTimeFormat("en-AU", {
      timeZone: "Australia/Sydney", year: "numeric", month: "2-digit", day: "2-digit"
    }).formatToParts(now);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${values.year}-${values.month}-${values.day}`;
  }

  function periodFor(calendar, date) {
    const periods = [
      ...calendar.teachingWeeks,
      { ...calendar.midSemesterBreak, message: "This is the mid-semester break" },
      { ...calendar.studyVacation, message: "This is the study vacation" },
      { ...calendar.examinations, message: "This is the examination period" }
    ];
    return periods.find((period) => date >= period.start && date <= period.end);
  }

  function messageFor(calendar, date) {
    if (date < calendar.start) {
      const days = Math.round((utcDay(calendar.start) - utcDay(date)) / 86400000);
      if (days === 1) return `${calendar.label} begins tomorrow`;
      const weeks = Math.floor(days / 7);
      const remainingDays = days % 7;
      const parts = [];
      if (weeks) parts.push(`${weeks} week${weeks === 1 ? "" : "s"}`);
      if (remainingDays) parts.push(`${remainingDays} day${remainingDays === 1 ? "" : "s"}`);
      return `${calendar.label} begins in ${parts.join(" and ")}`;
    }
    const period = periodFor(calendar, date);
    if (period?.week) return `This is Week ${String(period.week).padStart(2, "0")}`;
    return period?.message ?? `${calendar.label} has finished`;
  }

  const api = { isDate, sydneyDate, periodFor, messageFor };
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.BedaCalendar = api;
})(globalThis);
