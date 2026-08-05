#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const repoRoot = path.resolve(__dirname, "..");
const partial = fs.readFileSync(
  path.join(repoRoot, "_partials", "display-preference.html"),
  "utf8"
);
const script = partial.match(/<script>([\s\S]*)<\/script>/)?.[1];
assert.ok(script, "display preference partial should contain a script");

const quartoConfig = fs.readFileSync(path.join(repoRoot, "_quarto.yml"), "utf8");
const css = fs.readFileSync(
  path.join(repoRoot, "assets", "display-preference.css"),
  "utf8"
);

assert.match(quartoConfig, /- _partials\/display-preference\.html/);
assert.match(quartoConfig, /- assets\/display-preference\.css/);

function relativeLuminance(hex) {
  const channels = [1, 3, 5].map((index) =>
    Number.parseInt(hex.slice(index, index + 2), 16) / 255
  );
  const linear = channels.map((channel) =>
    channel <= 0.04045
      ? channel / 12.92
      : ((channel + 0.055) / 1.055) ** 2.4
  );
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

function contrastRatio(foreground, background) {
  const luminances = [
    relativeLuminance(foreground),
    relativeLuminance(background)
  ].sort((a, b) => b - a);
  return (luminances[0] + 0.05) / (luminances[1] + 0.05);
}

const colour = (name) =>
  css.match(new RegExp(`${name}:\\s*(#[0-9a-f]{6})`, "i"))?.[1];
const manilaBackground = colour("--beda-manila-bg");

for (const property of ["--bs-body-color", "--bs-link-color", "--bs-secondary-color"]) {
  const foreground = colour(property);
  assert.ok(foreground, `${property} should have an explicit colour`);
  assert.ok(
    contrastRatio(foreground, manilaBackground) >= 4.5,
    `${property} should meet WCAG AA contrast on the manila background`
  );
}

function createElement(tagName) {
  const attributes = new Map();
  const listeners = new Map();
  return {
    tagName,
    children: [],
    append(...children) {
      this.children.push(...children);
    },
    addEventListener(name, listener) {
      listeners.set(name, listener);
    },
    click() {
      listeners.get("click")?.();
    },
    getAttribute(name) {
      return attributes.get(name) ?? null;
    },
    setAttribute(name, value) {
      attributes.set(name, String(value));
    }
  };
}

function run(initialPreference = null) {
  const dataset = {};
  const tools = {
    children: [],
    append(element) {
      this.children.push(element);
    }
  };
  const listeners = new Map();
  const storage = new Map();
  if (initialPreference !== null) storage.set("beda-display-preference", initialPreference);

  const document = {
    documentElement: { dataset },
    readyState: "loading",
    addEventListener(name, listener) {
      listeners.set(name, listener);
    },
    createElement,
    getElementById() {
      return null;
    },
    querySelector(selector) {
      return selector === ".quarto-navbar-tools" ? tools : null;
    }
  };
  const localStorage = {
    getItem: (key) => storage.get(key) ?? null,
    removeItem: (key) => storage.delete(key),
    setItem: (key, value) => storage.set(key, value)
  };

  vm.runInNewContext(script, { document, window: { localStorage } });
  listeners.get("DOMContentLoaded")();

  const button = tools.children[0];
  return { button, dataset, storage };
}

const standard = run();
assert.equal(standard.dataset.bedaDisplay, undefined);
assert.equal(standard.button.getAttribute("aria-label"), "Manila background");
assert.equal(standard.button.getAttribute("aria-pressed"), "false");
assert.equal(standard.button.children.length, 1);
assert.equal(standard.button.children[0].className, "beda-display-swatch");

standard.button.click();
assert.equal(standard.dataset.bedaDisplay, "manila");
assert.equal(standard.storage.get("beda-display-preference"), "manila");
assert.equal(standard.button.getAttribute("aria-pressed"), "true");

standard.button.click();
assert.equal(standard.dataset.bedaDisplay, undefined);
assert.equal(standard.storage.has("beda-display-preference"), false);
assert.equal(standard.button.getAttribute("aria-pressed"), "false");

const remembered = run("manila");
assert.equal(remembered.dataset.bedaDisplay, "manila");
assert.equal(remembered.button.getAttribute("aria-pressed"), "true");

console.log("PASS: HTML display preference toggle");
