import fs from "node:fs";
import { settings, calendar } from "./semester-settings.mjs";

// Browser code uses a generated copy; _semester.json is the only editable source.
const breakTitle = `"${calendar.midSemesterBreak.title.replaceAll('"', '""')}"`;
const outputs = new Map([
  ["scripts/semester-config.js", `// Generated from _semester.json; run node scripts/sync-semester-settings.mjs.\nwindow.BedaSemester = ${JSON.stringify(settings, null, 2)};\n`],
  ["data/semester_breaks.csv", `after_week,title,start_date,end_date\n${calendar.midSemesterBreak.afterWeek},${breakTitle},${calendar.midSemesterBreak.start},${calendar.midSemesterBreak.displayEnd}\n`]
]);
const check = process.argv.includes("--check");
for (const [name, content] of outputs) {
  const file = new URL(`../${name}`, import.meta.url);
  const current = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";
  if (current === content) continue;
  if (check) throw new Error(`${name} is stale. Run node scripts/sync-semester-settings.mjs.`);
  fs.writeFileSync(file, content);
}
