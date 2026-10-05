(() => {
  "use strict";

  const semester = window.BedaSemester["semester-calendar"];
  const { sydneyDate, periodFor, messageFor } = window.BedaCalendar;

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
      if (status) status.textContent = `${messageFor(semester, date)}.`;
      highlightScheduleWeek(1, "Coming up", false);
      highlightModule2TimelineWeek(null);
      return;
    }

    const period = periodFor(semester, date);
    if (status) status.textContent = `${messageFor(semester, date)}.`;

    highlightScheduleWeek(period?.week ?? null);
    highlightModule2TimelineWeek(period?.week);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updatePage, { once: true });
  } else {
    updatePage();
  }
})();
