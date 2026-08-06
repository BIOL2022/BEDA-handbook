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
const darkTheme = fs.readFileSync(
  path.join(repoRoot, "assets", "theme-dark.scss"),
  "utf8"
);

assert.match(quartoConfig, /light:\s*zephyr/);
assert.match(quartoConfig, /dark:\s*\n\s*- zephyr\s*\n\s*- assets\/theme-dark\.scss/);
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

const cssColour = (name) =>
  css.match(new RegExp(`${name}:\\s*(#[0-9a-f]{6})`, "i"))?.[1];
const scssColour = (name) =>
  darkTheme.match(new RegExp(`\\${name}:\\s*(#[0-9a-f]{6})`, "i"))?.[1];

const manilaBackground = cssColour("--beda-manila-bg");
for (const property of ["--bs-body-color", "--bs-link-color", "--bs-secondary-color"]) {
  const foreground = cssColour(property);
  assert.ok(foreground, `${property} should have an explicit Manila colour`);
  assert.ok(
    contrastRatio(foreground, manilaBackground) >= 4.5,
    `${property} should meet WCAG AA contrast on Manila`
  );
}

const darkBackground = scssColour("$body-bg");
for (const property of ["$body-color", "$link-color", "$secondary-color"]) {
  const foreground = scssColour(property);
  assert.ok(foreground, `${property} should have an explicit dark-mode colour`);
  assert.ok(
    contrastRatio(foreground, darkBackground) >= 4.5,
    `${property} should meet WCAG AA contrast in Dark mode`
  );
}

function createClassList(element) {
  const values = new Set();
  return {
    add(...names) {
      for (const name of names) values.add(name);
    },
    contains(name) {
      return values.has(name);
    },
    remove(...names) {
      for (const name of names) values.delete(name);
    },
    toggle(name, force) {
      const enabled = force === undefined ? !values.has(name) : force;
      if (enabled) values.add(name);
      else values.delete(name);
      return enabled;
    },
    setFromString(value) {
      values.clear();
      for (const name of String(value).split(/\s+/).filter(Boolean)) values.add(name);
    },
    toString() {
      return [...values].join(" ");
    }
  };
}

function createElement(tagName) {
  const attributes = new Map();
  const listeners = new Map();
  const element = {
    tagName: tagName.toUpperCase(),
    children: [],
    dataset: {},
    hidden: false,
    checked: false,
    focused: false,
    append(...children) {
      this.children.push(...children);
    },
    addEventListener(name, listener) {
      if (!listeners.has(name)) listeners.set(name, []);
      listeners.get(name).push(listener);
    },
    dispatch(name, event = {}) {
      for (const listener of listeners.get(name) ?? []) {
        listener({
          target: this,
          preventDefault() {},
          stopPropagation() {},
          ...event
        });
      }
    },
    click() {
      this.dispatch("click");
    },
    change() {
      this.dispatch("change");
    },
    contains(target) {
      return this === target || this.children.some((child) => child.contains?.(target));
    },
    focus() {
      this.focused = true;
    },
    getAttribute(name) {
      return attributes.get(name) ?? null;
    },
    setAttribute(name, value) {
      attributes.set(name, String(value));
    }
  };
  element.classList = createClassList(element);
  Object.defineProperty(element, "className", {
    get: () => element.classList.toString(),
    set: (value) => element.classList.setFromString(value)
  });
  return element;
}

function descendants(element) {
  return element.children.flatMap((child) => [child, ...descendants(child)]);
}

function run(initialPreference = null) {
  const root = createElement("html");
  const body = createElement("body");
  body.classList.add("quarto-light");
  const tools = createElement("div");
  tools.className = "quarto-navbar-tools";
  const documentListeners = new Map();
  const storage = new Map();
  if (initialPreference !== null) {
    storage.set("beda-display-preference", initialPreference);
  }

  const document = {
    documentElement: root,
    body,
    readyState: "loading",
    addEventListener(name, listener) {
      if (!documentListeners.has(name)) documentListeners.set(name, []);
      documentListeners.get(name).push(listener);
    },
    createElement,
    getElementById(id) {
      return descendants(tools).find((element) => element.id === id) ?? null;
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

  const window = {
    localStorage,
    requestAnimationFrame(callback) {
      callback();
    },
    quartoToggleColorScheme() {
      const toDark = !body.classList.contains("quarto-dark");
      body.classList.toggle("quarto-dark", toDark);
      body.classList.toggle("quarto-light", !toDark);
      storage.set("quarto-color-scheme", toDark ? "alternate" : "default");
    }
  };

  vm.runInNewContext(script, { document, window });

  const startsDark = storage.get("quarto-color-scheme") === "alternate";
  body.classList.toggle("quarto-dark", startsDark);
  body.classList.toggle("quarto-light", !startsDark);
  for (const listener of documentListeners.get("DOMContentLoaded") ?? []) listener();

  const picker = tools.children[0];
  const button = picker.children[0];
  const panel = picker.children[1];
  const inputs = descendants(panel).filter((element) => element.tagName === "INPUT");
  return { body, button, inputs, panel, picker, root, storage };
}

function choose(state, mode) {
  state.button.click();
  const input = state.inputs.find((candidate) => candidate.value === mode);
  input.checked = true;
  input.change();
}

const display = run();
assert.ok(display.root.classList.contains("beda-display-control"));
assert.equal(display.root.dataset.bedaDisplay, undefined);
assert.equal(display.storage.get("quarto-color-scheme"), "default");
assert.equal(display.button.getAttribute("aria-label"), "Display: Default");
assert.equal(display.button.getAttribute("aria-expanded"), "false");
assert.equal(display.panel.hidden, true);
assert.equal(display.inputs.length, 3);
assert.equal(display.inputs.find((input) => input.value === "default").checked, true);

display.button.click();
assert.equal(display.panel.hidden, false);
assert.equal(display.button.getAttribute("aria-expanded"), "true");

choose(display, "manila");
assert.equal(display.root.dataset.bedaDisplay, "manila");
assert.equal(display.body.classList.contains("quarto-dark"), false);
assert.equal(display.storage.get("beda-display-preference"), "manila");
assert.equal(display.storage.get("quarto-color-scheme"), "default");
assert.equal(display.button.getAttribute("aria-label"), "Display: Manila");
assert.equal(display.panel.hidden, true);

choose(display, "dark");
assert.equal(display.root.dataset.bedaDisplay, undefined);
assert.equal(display.body.classList.contains("quarto-dark"), true);
assert.equal(display.storage.get("beda-display-preference"), "dark");
assert.equal(display.storage.get("quarto-color-scheme"), "alternate");
assert.equal(display.button.getAttribute("aria-label"), "Display: Dark");

choose(display, "default");
assert.equal(display.body.classList.contains("quarto-light"), true);
assert.equal(display.storage.has("beda-display-preference"), false);
assert.equal(display.storage.get("quarto-color-scheme"), "default");
assert.equal(display.button.getAttribute("aria-label"), "Display: Default");

const rememberedManila = run("manila");
assert.equal(rememberedManila.root.dataset.bedaDisplay, "manila");
assert.equal(rememberedManila.button.getAttribute("aria-label"), "Display: Manila");

const rememberedDark = run("dark");
assert.equal(rememberedDark.body.classList.contains("quarto-dark"), true);
assert.equal(rememberedDark.root.dataset.bedaDisplay, undefined);
assert.equal(rememberedDark.button.getAttribute("aria-label"), "Display: Dark");

console.log("PASS: Default, Manila and Dark display selector");
