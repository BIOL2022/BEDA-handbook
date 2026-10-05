const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const settings = require("../../_semester.json");

const root = path.resolve(__dirname, "../..");
const filter = path.join(root, "filters/semester-links.lua");
const course = (name) => settings.website.navbar.right
  .find((item) => item.text === name).href.replace(/\/$/, "");

for (const directory of [root, path.join(root, "lectures/L06")]) {
  test(`semester links resolve without Quarto project context from ${path.relative(root, directory) || "root"}`, () => {
    const result = spawnSync("quarto", [
      "pandoc", "--from", "markdown", "--to", "html", "--lua-filter", filter
    ], {
      cwd: directory,
      encoding: "utf8",
      input: [
        "[Canvas](canvas:/assignments/123)",
        "[Ed](ed:)",
        '<div><a href="canvas:/pages/help">Help</a></div>',
        'Inline <a href="ed:/lessons/123">Lesson</a>.',
        "[Other](https://example.invalid/)"
      ].join("\n\n")
    });

    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    for (const destination of [
      `${course("Canvas")}/assignments/123`, course("Ed"),
      `${course("Canvas")}/pages/help`, `${course("Ed")}/lessons/123`,
      "https://example.invalid/"
    ]) assert.ok(result.stdout.includes(`href="${destination}"`), destination);
    assert.doesNotMatch(result.stdout, /href="(?:canvas|ed):/);
  });
}
