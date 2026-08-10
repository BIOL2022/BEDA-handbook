(() => {
  "use strict";

  const semester = {
    label: "Semester 2",
    start: "2026-08-03",
    periods: [
      { start: "2026-08-03", end: "2026-08-09", week: 1, message: "This is Week 01." },
      { start: "2026-08-10", end: "2026-08-16", week: 2, message: "This is Week 02." },
      { start: "2026-08-17", end: "2026-08-23", week: 3, message: "This is Week 03." },
      { start: "2026-08-24", end: "2026-08-30", week: 4, message: "This is Week 04." },
      { start: "2026-08-31", end: "2026-09-06", week: 5, message: "This is Week 05." },
      { start: "2026-09-07", end: "2026-09-13", week: 6, message: "This is Week 06." },
      { start: "2026-09-14", end: "2026-09-20", week: 7, message: "This is Week 07." },
      { start: "2026-09-21", end: "2026-09-27", week: 8, message: "This is Week 08." },
      {
        start: "2026-09-28",
        end: "2026-10-05",
        message: "This is the mid-semester break."
      },
      { start: "2026-10-06", end: "2026-10-11", week: 9, message: "This is Week 09." },
      { start: "2026-10-12", end: "2026-10-18", week: 10, message: "This is Week 10." },
      { start: "2026-10-19", end: "2026-10-25", week: 11, message: "This is Week 11." },
      { start: "2026-10-26", end: "2026-11-01", week: 12, message: "This is Week 12." },
      { start: "2026-11-02", end: "2026-11-08", week: 13, message: "This is Week 13." },
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

  function highlightScheduleWeek(week, label = "Current", isCurrent = true) {
    const rows = Array.from(document.querySelectorAll("#weekly-content tbody tr"));
    const mobileWeeks = Array.from(
      document.querySelectorAll("#weekly-content .weekly-mobile-week")
    );
    const jumpLink = document.querySelector(
      "#weekly-content .weekly-current-week-jump"
    );

    for (const row of rows) {
      row.classList.remove("is-current-week");
      row.removeAttribute("aria-current");
      row.cells[0]?.querySelector(".current-week-label")?.remove();
    }
    for (const mobileWeek of mobileWeeks) {
      mobileWeek.classList.remove("is-current-week");
      mobileWeek.removeAttribute("aria-current");
      const marker = mobileWeek.querySelector(".weekly-mobile-current-label");
      if (marker) {
        marker.hidden = true;
        marker.textContent = "";
      }
    }

    if (!Number.isInteger(week)) {
      if (jumpLink) jumpLink.hidden = true;
      return;
    }

    const currentRow = rows.find(
      (row) => Number(row.cells[0]?.textContent.trim()) === week
    );
    if (currentRow) {
      currentRow.classList.add("is-current-week");
      if (isCurrent) currentRow.setAttribute("aria-current", "true");

      const marker = document.createElement("span");
      marker.className = "current-week-label";
      marker.textContent = label;
      currentRow.cells[0].append(marker);
    }

    const currentMobileWeek = mobileWeeks.find(
      (mobileWeek) => Number(mobileWeek.dataset.scheduleWeek) === week
    );
    if (currentMobileWeek) {
      currentMobileWeek.classList.add("is-current-week");
      if (isCurrent) currentMobileWeek.setAttribute("aria-current", "true");

      const marker = currentMobileWeek.querySelector(
        ".weekly-mobile-current-label"
      );
      if (marker) {
        marker.textContent = label === "Current" ? "Current week" : label;
        marker.hidden = false;
      }
    }

    if (jumpLink) {
      jumpLink.href = `#mobile-week-${week}`;
      jumpLink.hidden = !currentMobileWeek;
    }
  }

  function highlightModule2TimelineWeek(week) {
    const rows = Array.from(
      document.querySelectorAll(".module2-timeline-table tbody tr")
    );

    for (const row of rows) {
      row.classList.remove("is-current-week");
      row.removeAttribute("aria-current");
      row.cells[0]?.querySelector(".module2-current-label")?.remove();
    }

    if (!Number.isInteger(week) || week < 2 || week > 8) return;

    const expectedLabel = week < 4 ? "Weeks 2–3" : `Week ${week}`;
    const currentRow = rows.find(
      (row) => row.cells[0]?.textContent.trim().startsWith(expectedLabel)
    );
    if (!currentRow) return;

    currentRow.classList.add("is-current-week");
    currentRow.setAttribute("aria-current", "true");

    const marker = document.createElement("span");
    marker.className = "module2-current-label";
    marker.textContent = "You are here";
    currentRow.cells[0].append(marker);
  }

  function updatePage() {
    const status = document.getElementById("semester-status");
    const date = sydneyDate();

    if (date < semester.start) {
      if (status) status.textContent = countdown(semester.start, date);
      highlightScheduleWeek(1, "Coming up", false);
      highlightModule2TimelineWeek(null);
      return;
    }

    const period = semester.periods.find(
      (value) => date >= value.start && date <= value.end
    );

    if (status) {
      status.textContent = period
        ? period.message
        : `${semester.label} has finished.`;
    }

    highlightScheduleWeek(period?.week ?? null);
    highlightModule2TimelineWeek(period?.week);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updatePage, { once: true });
  } else {
    updatePage();
  }
})();
