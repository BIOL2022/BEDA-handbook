import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const schedules = {
  "2026-s2": {
    label: "Semester 2",
    start: "2026-08-03",
    teachingWeeks: [
      { week: 1, start: "2026-08-03", end: "2026-08-09" },
      { week: 2, start: "2026-08-10", end: "2026-08-16" },
      { week: 3, start: "2026-08-17", end: "2026-08-23" },
      { week: 4, start: "2026-08-24", end: "2026-08-30" },
      { week: 5, start: "2026-08-31", end: "2026-09-06" },
      { week: 6, start: "2026-09-07", end: "2026-09-13" },
      { week: 7, start: "2026-09-14", end: "2026-09-20" },
      { week: 8, start: "2026-09-21", end: "2026-09-27" },
      { week: 9, start: "2026-10-06", end: "2026-10-11" },
      { week: 10, start: "2026-10-12", end: "2026-10-18" },
      { week: 11, start: "2026-10-19", end: "2026-10-25" },
      { week: 12, start: "2026-10-26", end: "2026-11-01" },
      { week: 13, start: "2026-11-02", end: "2026-11-08" }
    ],
    midSemesterBreak: { start: "2026-09-28", end: "2026-10-05" },
    studyVacation: { start: "2026-11-09", end: "2026-11-15" },
    examinations: { start: "2026-11-16", end: "2026-11-28" }
  }
};

function sydneyDate() {
  const parts = new Intl.DateTimeFormat("en-AU", {
    timeZone: "Australia/Sydney",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(new Date());
  const values = Object.fromEntries(
    parts
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value])
  );

  return `${values.year}-${values.month}-${values.day}`;
}

function utcDay(date) {
  const [year, month, day] = date.split("-").map(Number);
  return Date.UTC(year, month - 1, day);
}

function includesDate(range, date) {
  return date >= range.start && date <= range.end;
}

function plural(value, word) {
  return `${value} ${word}${value === 1 ? "" : "s"}`;
}

function countdown(label, start, date) {
  const days = Math.round((utcDay(start) - utcDay(date)) / 86400000);

  if (days === 1) {
    return `${label} begins tomorrow`;
  }

  const weeks = Math.floor(days / 7);
  const remainingDays = days % 7;
  const parts = [];

  if (weeks > 0) {
    parts.push(plural(weeks, "week"));
  }

  if (remainingDays > 0) {
    parts.push(plural(remainingDays, "day"));
  }

  return `${label} begins in ${parts.join(" and ")}`;
}

export function messageFor(schedule, date) {
  if (date < schedule.start) {
    return countdown(schedule.label, schedule.start, date);
  }

  const teachingWeek = schedule.teachingWeeks.find((week) =>
    includesDate(week, date)
  );

  if (teachingWeek) {
    return `This is Week ${String(teachingWeek.week).padStart(2, "0")}`;
  }

  if (includesDate(schedule.midSemesterBreak, date)) {
    return "This is the mid-semester break";
  }

  if (includesDate(schedule.studyVacation, date)) {
    return "This is the study vacation";
  }

  if (includesDate(schedule.examinations, date)) {
    return "This is the examination period";
  }

  return `${schedule.label} has finished`;
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function balancedLines(message) {
  if (message.length <= 28) {
    return [message];
  }

  const words = message.split(" ");
  let best = [message];
  let bestScore = Number.POSITIVE_INFINITY;

  for (let index = 1; index < words.length; index += 1) {
    const first = words.slice(0, index).join(" ");
    const second = words.slice(index).join(" ");
    const score = Math.max(first.length, second.length) * 10
      + Math.abs(first.length - second.length);

    if (score < bestScore) {
      best = [first, second];
      bestScore = score;
    }
  }

  return best;
}

export function svgFor(message, narrow = false) {
  const safeMessage = escapeXml(message);
  const width = narrow ? 320 : 600;
  const fontSize = narrow ? 18 : 23;
  const lines = narrow ? balancedLines(message).map(escapeXml) : [safeMessage];
  const text = lines.length === 1
    ? `<text x="${width / 2}" y="32" text-anchor="middle" dominant-baseline="middle">${lines[0]}</text>`
    : lines.map((line, index) =>
      `<text x="${width / 2}" y="${index === 0 ? 21 : 45}" text-anchor="middle" dominant-baseline="middle">${line}</text>`
    ).join("\n  ");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="64" viewBox="0 0 ${width} 64" role="img" aria-labelledby="semester-status-title semester-status-description">
  <title id="semester-status-title">Current BIOL2022 teaching period</title>
  <desc id="semester-status-description">${safeMessage}</desc>
  <style>text { fill: #440154; font-family: Lato, "Helvetica Neue", Arial, sans-serif; font-size: ${fontSize}px; font-weight: 400; }</style>
  ${text}
</svg>
`;
}

function optionsFrom(argv) {
  const options = {
    date: sydneyDate(),
    year: "2026",
    semester: "2",
    output: path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      "../canvas/semester-status.svg"
    ),
    narrowOutput: path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      "../canvas/semester-status-narrow.svg"
    )
  };

  for (let index = 0; index < argv.length; index += 1) {
    const name = argv[index];
    const value = argv[index + 1];

    if (["--date", "--year", "--semester", "--output", "--narrow-output"].includes(name)) {
      const key = name === "--narrow-output" ? "narrowOutput" : name.slice(2);
      options[key] = value;
      index += 1;
    }
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(options.date)) {
    throw new Error(`Invalid date: ${options.date}`);
  }

  return options;
}

export function generate(options) {
  const schedule = schedules[`${options.year}-s${options.semester}`];
  const message = schedule
    ? messageFor(schedule, options.date)
    : "Semester schedule unavailable";
  const output = path.resolve(options.output);
  const narrowOutput = path.resolve(options.narrowOutput);

  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.mkdirSync(path.dirname(narrowOutput), { recursive: true });
  fs.writeFileSync(output, svgFor(message));
  fs.writeFileSync(narrowOutput, svgFor(message, true));

  return { date: options.date, message, output, narrowOutput };
}

if (process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const result = generate(optionsFrom(process.argv.slice(2)));
  console.log(`${result.message} -> ${result.output}, ${result.narrowOutput}`);
}
