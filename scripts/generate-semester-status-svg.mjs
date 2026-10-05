import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { calendar, settings, scheduleKey } from "./semester-settings.mjs";
import calendarApi from "./semester-calendar.js";

export const schedules = { [scheduleKey]: calendar };
export const messageFor = calendarApi.messageFor;

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
    date: calendarApi.sydneyDate(),
    year: String(settings["edition-year"]),
    semester: String(settings["edition-semester"]),
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

  if (!calendarApi.isDate(options.date)) {
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
