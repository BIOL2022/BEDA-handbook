(() => {
  "use strict";

  const semester = {
    label: "Semester 2",
    start: "2026-08-03",
    periods: [
      { start: "2026-08-03", end: "2026-08-09", message: "This is Week 01." },
      { start: "2026-08-10", end: "2026-08-16", message: "This is Week 02." },
      { start: "2026-08-17", end: "2026-08-23", message: "This is Week 03." },
      { start: "2026-08-24", end: "2026-08-30", message: "This is Week 04." },
      { start: "2026-08-31", end: "2026-09-06", message: "This is Week 05." },
      { start: "2026-09-07", end: "2026-09-13", message: "This is Week 06." },
      { start: "2026-09-14", end: "2026-09-20", message: "This is Week 07." },
      { start: "2026-09-21", end: "2026-09-27", message: "This is Week 08." },
      {
        start: "2026-09-28",
        end: "2026-10-05",
        message: "This is the mid-semester break."
      },
      { start: "2026-10-06", end: "2026-10-11", message: "This is Week 09." },
      { start: "2026-10-12", end: "2026-10-18", message: "This is Week 10." },
      { start: "2026-10-19", end: "2026-10-25", message: "This is Week 11." },
      { start: "2026-10-26", end: "2026-11-01", message: "This is Week 12." },
      { start: "2026-11-02", end: "2026-11-08", message: "This is Week 13." },
      {
        start: "2026-11-09",
        end: "2026-11-15",
        message: "This is the study vacation."
      },
      {
        start: "2026-11-16",
        end: "2026-11-28",
        message: "This is the examination period."
      }
    ]
  };

  const status = document.getElementById("semester-status");
  if (!status) return;

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

  function plural(value, word) {
    return `${value} ${word}${value === 1 ? "" : "s"}`;
  }

  function countdown(start, date) {
    const days = Math.round((utcDay(start) - utcDay(date)) / 86400000);

    if (days === 1) return `${semester.label} begins tomorrow.`;

    const weeks = Math.floor(days / 7);
    const remainingDays = days % 7;
    const parts = [];

    if (weeks > 0) parts.push(plural(weeks, "week"));
    if (remainingDays > 0) parts.push(plural(remainingDays, "day"));

    return `${semester.label} begins in ${parts.join(" and ")}.`;
  }

  const date = sydneyDate();

  if (date < semester.start) {
    status.textContent = countdown(semester.start, date);
    return;
  }

  const period = semester.periods.find(
    (value) => date >= value.start && date <= value.end
  );

  status.textContent = period
    ? period.message
    : `${semester.label} has finished.`;
})();
