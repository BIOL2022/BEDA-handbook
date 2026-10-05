const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const checker = path.resolve(__dirname, "../check_navigation.js");
const link = (href, text) => `<a href="${href}">${text}</a>`;
const canonical = (file) => `https://biol2022.github.io/BEDA-handbook/${file}`;

function schedule() {
  const rows = [];
  const mobile = [];
  for (let week = 1; week <= 13; week += 1) {
    const lecture = week <= 12
      ? link(`lectures/L${String(week).padStart(2, "0")}/index.html`, `Lecture ${week}`)
      : "Exam revision";
    let practical = "No practical";
    if (week <= 3) practical = link(`module01/10${week + 1}-week0${week}.html`, `Practical ${week}`);
    if ([4, 5, 7, 8].includes(week)) practical = link("module02/202-timeline.html", "Module 2 timeline");
    if (week === 4) practical += link("module02/200-welcome.html", "Welcome to Module 2 Practicals");
    if (week === 9) practical = link("module03/302-week09.html", "Practical 9");
    if (week === 10) practical = link("module03/303-week10.html", "Practical 10");
    const notes = week === 1 ? link("prerequisites.html", "Am I ready?")
      : week === 3 ? link("module02/203-projects.html", "Report 1 Projects") : "—";
    const resources = lecture + practical;
    rows.push(`<tr><th scope="row">${week}</th><td>${resources}</td><td>${notes}</td></tr>`);
    mobile.push(`<section class="weekly-mobile-week" id="mobile-week-${week}" data-schedule-week="${week}" aria-labelledby="mobile-week-${week}-title">
      <h3 id="mobile-week-${week}-title">Week ${week}</h3>${resources}${notes}</section>`);
    if (week === 8) {
      rows.push('<tr><th scope="row">Break</th><td>Mid-semester break — dates</td><td></td></tr>');
      mobile.push('<section class="weekly-mobile-break">Mid-semester break — dates</section>');
    }
  }
  return `<div id="weekly-content" role="region" aria-label="Weekly content schedule">
    <div class="weekly-schedule-desktop table-responsive" tabindex="0"><table>
      <thead><tr><th>Week</th><th>Resources</th><th>Notes</th></tr></thead><tbody>${rows.join("")}</tbody>
    </table></div><div class="weekly-schedule-mobile">
      <a class="weekly-current-week-jump" href="#mobile-week-1" hidden>Jump to current week</a>${mobile.join("")}
    </div></div>`;
}

function themeLinks() {
  return ["primary", "alternate", "extra"].flatMap((role) => {
    const classes = role === "extra" ? "quarto-color-scheme-extra"
      : `quarto-color-scheme${role === "alternate" ? " quarto-color-alternate" : ""}`;
    return [
      `<link id="quarto-bootstrap" class="${classes}" rel="stylesheet" href="site_libs/bootstrap/bootstrap-${role}.min.css">`,
      `<link id="quarto-text-highlighting-styles" class="${classes}" rel="stylesheet" href="site_libs/quarto-html/quarto-syntax-highlighting-${role}.css">`,
    ];
  }).join("");
}

function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "beda-navigation-test-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  function write(file, html) {
    const target = path.join(directory, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, html);
  }
  function change(file, transform) {
    write(file, transform(fs.readFileSync(path.join(directory, file), "utf8")));
  }
  const navbar = '<header id="quarto-header">' + [
    ["index.html", "Home"], ["unit-information.html", "About"], ["updates.html", "Updates"],
    ["help.html", "Contact"], ["cheatsheets.html", "Cheatsheets"],
    ["https://canvas.sydney.edu.au/", "Canvas"], ["https://edstem.org/", "Ed"],
  ].map(([href, text]) => link(href, text)).join("") + "</header>";
  write("index.html", themeLinks() + navbar + schedule());
  write("schedule.html", schedule());
  for (const file of ["updates.html", "help.html", "cheatsheets.html", "prerequisites.html",
    "module01/102-week01.html", "module01/105-images.html", "module01/106-species-id.html",
    "module01/w03-model-fitting-assumptions.html", "module03/301-intro.html"]) write(file, "<p>Published content</p>");
  write("unit-information.html", '<h2 id="modules">Modules</h2>' + link("prerequisites.html", "Prerequisites"));
  write("module01/103-week02.html", link(canonical("module01/105-images.html"), "Images") + link(canonical("module01/106-species-id.html"), "Species"));
  write("module01/104-week03.html", link("w03-model-fitting-assumptions.html", "Assumptions"));
  write("module03/302-week09.html", '<h2 id="install-miso">Install miso</h2>' + link("301-intro.html", "Introduction"));
  write("module03/303-week10.html", link("302-week09.html#install-miso", "Install miso"));
  const module2Pages = ["200-welcome", "201-overview", "203-projects", "204-report1", "205-resources", "206-rubric"];
  for (const name of module2Pages) write(`module02/${name}.html`, "<p>Module 2</p>");
  const timelineRows = ["Weeks 2–3", "Week 4", "Week 5", "Week 6", "Week 7", "Week 8"]
    .map((label) => `<tr><td>${label}<br>Dates</td><td>In class</td><td>Own time</td></tr>`).join("");
  write("module02/202-timeline.html", module2Pages.map((name) => link(`${name}.html`, name)).join("") +
    `<div class="module2-timeline-table" role="region" aria-label="Module 2 timeline" tabindex="0"><table>
    <tr><th>Week</th><th>In your timetabled session</th><th>Between practical sessions<br>and in your own time</th></tr>
    ${timelineRows}</table></div>`);
  for (let week = 1; week <= 12; week += 1) write(`lectures/L${String(week).padStart(2, "0")}/index.html`, "<p>Lecture</p>");
  return {
    write, change,
    run: () => spawnSync(process.execPath, [checker, directory], { encoding: "utf8" }),
  };
}

function expectFailure(result, pattern) {
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, pattern);
}

test("current navigation and both schedule layouts pass without unpublished draft pages", (t) => {
  const result = fixture(t).run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /^PASS:/);
});

test("content IDs remain unique, including collisions with Quarto stylesheet IDs", (t) => {
  const site = fixture(t);
  site.change("index.html", (html) => html + '<h2 id="content">One</h2><h2 id="content">Two</h2><div id="quarto-bootstrap">Collision</div>');
  const result = site.run();
  expectFailure(result, /duplicate id "content"/);
  assert.match(result.stderr, /duplicate id "quarto-bootstrap"/);
});

test("duplicate theme roles and unrecognised stylesheet assets are rejected", (t) => {
  const site = fixture(t);
  site.change("index.html", (html) => html + '<link id="quarto-bootstrap" class="quarto-color-scheme" rel="stylesheet" href="site_libs/bootstrap/bootstrap-extra-copy.min.css">');
  expectFailure(site.run(), /duplicate id "quarto-bootstrap"/);
  site.change("index.html", (html) => html.replace("site_libs/quarto-html/quarto-syntax-highlighting-extra.css", "assets/custom.css"));
  expectFailure(site.run(), /duplicate id "quarto-text-highlighting-styles"/);
});

test("relative and same-site absolute links still detect missing files and fragments", (t) => {
  const site = fixture(t);
  site.change("updates.html", (html) => html + link("missing.html", "Missing") + link(canonical("unit-information.html#missing"), "Missing section"));
  const result = site.run();
  expectFailure(result, /links to missing file "missing.html"/);
  assert.match(result.stderr, /links to missing fragment "https:\/\/biol2022.github.io\/BEDA-handbook\/unit-information.html#missing"/);
});

test("site-root URLs resolve from nested pages; another GitHub Pages project remains external", (t) => {
  const site = fixture(t);
  site.change("module03/303-week10.html", (html) => html + link("/BEDA-handbook/unit-information.html#modules", "Modules") + link("https://biol2022.github.io/2026-lectures/not-local.html", "External deck"));
  const result = site.run();
  assert.equal(result.status, 0, result.stderr);
});

test("escaping the rendered site and linking an absent draft are failures", (t) => {
  const site = fixture(t);
  site.change("updates.html", (html) => html + link("../outside.html", "Outside") + link("lectures/L13/index.html", "Draft"));
  const result = site.run();
  expectFailure(result, /links outside rendered site "\.\.\/outside.html"/);
  assert.match(result.stderr, /links to missing file "lectures\/L13\/index.html"/);
});

test("mobile schedules preserve every desktop destination", (t) => {
  const site = fixture(t);
  site.change("index.html", (html) => html.replace('<h3 id="mobile-week-1-title">Week 1</h3><a href="lectures/L01/index.html">Lecture 1</a>', '<h3 id="mobile-week-1-title">Week 1</h3>Lecture 1'));
  expectFailure(site.run(), /mobile Week 1 links differ from the desktop schedule/);
});

test("mobile sections need ordered week IDs, labels and a jump link", (t) => {
  const site = fixture(t);
  site.change("schedule.html", (html) => html.replace('data-schedule-week="1"', 'data-schedule-week="2"').replace('class="weekly-current-week-jump"', 'class="other-link"'));
  const result = site.run();
  expectFailure(result, /schedule.html mobile Week 1 needs its ordered, labelled section/);
  assert.match(result.stderr, /schedule.html mobile schedule is missing its current-week jump link/);
});

test("the mobile schedule retains its responsive wrapper and semester break", (t) => {
  const site = fixture(t);
  site.change("schedule.html", (html) => html.replace('class="weekly-schedule-mobile"', 'class="other-wrapper"').replace('class="weekly-mobile-break"', 'class="other-entry"'));
  const result = site.run();
  expectFailure(result, /schedule.html is missing its mobile schedule wrapper/);
  assert.match(result.stderr, /schedule.html mobile schedule needs its semester-break entry/);
});

test("Module 2 requires its current grid-table periods", (t) => {
  const site = fixture(t);
  site.change("module02/202-timeline.html", (html) => html.replace("Week 7", "Week 9"));
  expectFailure(site.run(), /Module 2 timeline needs its six ordered periods/);
});

test("the About label and current contextual routes remain required", (t) => {
  const site = fixture(t);
  site.change("index.html", (html) => html.replace(">About</a>", ">Unit information</a>"));
  site.change("module02/202-timeline.html", (html) => html.replace(link("201-overview.html", "201-overview"), ""));
  const result = site.run();
  expectFailure(result, /missing visible label "About"/);
  assert.match(result.stderr, /missing a contextual link to module02\/201-overview.html/);
});
