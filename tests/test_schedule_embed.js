#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const siteRoot = path.join(repoRoot, "_site");
const indexPath = path.join(siteRoot, "index.html");
const schedulePath = path.join(siteRoot, "schedule.html");
const searchPath = path.join(siteRoot, "search.json");
const embedCssPath = path.join(repoRoot, "assets", "schedule-embed.css");

function read(file) {
  return fs.readFileSync(file, "utf8");
}

function normaliseHtml(value) {
  return value.replace(/\s+/g, " ").trim();
}

function scheduleTable(html) {
  const section = html.match(
    /<div\b[^>]*\bid=["']weekly-content["'][^>]*>[\s\S]*?<\/table>/i,
  );
  assert.ok(section, "page should contain the weekly-content table");

  const table = section[0].match(/<table\b[\s\S]*?<\/table>/i);
  assert.ok(table, "weekly-content should contain a table");
  return normaliseHtml(table[0]);
}

assert.ok(fs.existsSync(schedulePath), "schedule.html should be rendered");
assert.ok(fs.existsSync(embedCssPath), "schedule embed CSS should exist");

const indexHtml = read(indexPath);
const scheduleHtml = read(schedulePath);
const searchJson = fs.existsSync(searchPath) ? read(searchPath) : "";
const embedCss = read(embedCssPath);

assert.match(scheduleHtml, /id=["']semester-status["']/);
assert.match(scheduleHtml, /scripts\/semester-status\.js/);
assert.match(scheduleHtml, /id=["']weekly-content["']/);
assert.doesNotMatch(scheduleHtml, /Welcome to the BEDA handbook/);
assert.match(scheduleHtml, /<h1\b[^>]*class=["'][^"']*visually-hidden/);
assert.match(
  scheduleHtml,
  /name=["']robots["'][^>]*content=["']noindex, nofollow["']/,
);
assert.doesNotMatch(indexHtml, /href=["'][^"']*schedule\.html/);
assert.doesNotMatch(searchJson, /schedule\.html/);
assert.equal(scheduleTable(scheduleHtml), scheduleTable(indexHtml));
assert.match(embedCss, /#quarto-header[\s\S]*display:\s*none/);
assert.match(embedCss, /\.quarto-title-block[\s\S]*display:\s*none/);
assert.match(embedCss, /footer\.footer[\s\S]*display:\s*none/);

console.log("PASS: hidden schedule page");
