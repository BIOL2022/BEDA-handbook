#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const path = require("node:path");

const editionPath = path.resolve(__dirname, "..", "..", "_edition.yml");

function stripInlineComment(line, lineNumber) {
  let quote = null;
  let escaped = false;

  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];

    if (quote === '"') {
      if (escaped) {
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === quote) {
        quote = null;
      }
      continue;
    }

    if (quote === "'") {
      if (character === "'" && line[index + 1] === "'") {
        index += 1;
      } else if (character === quote) {
        quote = null;
      }
      continue;
    }

    if (character === '"' || character === "'") {
      quote = character;
    } else if (character === "#") {
      return line.slice(0, index);
    }
  }

  if (quote !== null) {
    throw new Error(
      `_edition.yml:${lineNumber}: unterminated ${quote} quoted string`,
    );
  }
  return line;
}

function parseScalar(rawValue, lineNumber) {
  const value = rawValue.trim();
  if (value.length === 0) {
    throw new Error(`_edition.yml:${lineNumber}: missing scalar value`);
  }

  if (value.startsWith('"')) {
    try {
      const parsed = JSON.parse(value);
      if (typeof parsed !== "string") {
        throw new Error("value is not a string");
      }
      return parsed;
    } catch (error) {
      throw new Error(
        `_edition.yml:${lineNumber}: invalid double-quoted string: ${error.message}`,
      );
    }
  }

  if (value.startsWith("'")) {
    if (!value.endsWith("'") || value.length < 2) {
      throw new Error(
        `_edition.yml:${lineNumber}: invalid single-quoted string`,
      );
    }
    return value.slice(1, -1).replace(/''/g, "'");
  }

  if (/^[+-]?\d+$/.test(value)) {
    const integer = Number(value);
    if (!Number.isSafeInteger(integer)) {
      throw new Error(`_edition.yml:${lineNumber}: integer is not safe`);
    }
    return integer;
  }

  return value;
}

function parseFlatYaml(filePath) {
  const source = fs.readFileSync(filePath, "utf8");
  const metadata = {};

  for (const [index, rawLine] of source.split(/\r?\n/).entries()) {
    const lineNumber = index + 1;
    const line = stripInlineComment(rawLine, lineNumber).trim();
    if (line.length === 0) {
      continue;
    }

    const match = line.match(/^([A-Za-z][\w-]*):\s*(.*)$/);
    if (!match) {
      throw new Error(
        `_edition.yml:${lineNumber}: expected a flat "key: value" entry`,
      );
    }

    const [, key, rawValue] = match;
    if (Object.hasOwn(metadata, key)) {
      throw new Error(`_edition.yml:${lineNumber}: duplicate key "${key}"`);
    }
    metadata[key] = parseScalar(rawValue, lineNumber);
  }

  return Object.freeze(metadata);
}

const edition = parseFlatYaml(editionPath);
const editionLabel = edition["edition-label"];
const semesterLabel =
  `Semester ${edition["edition-semester"]}, ${edition["edition-year"]}`;
const coverEditionLabel =
  `Semester ${edition["edition-semester"]} · ${edition["edition-year"]}`;
const colophonEditionLabel = `${editionLabel} · ${semesterLabel}`;

module.exports = {
  colophonEditionLabel,
  coverEditionLabel,
  edition,
  editionLabel,
  parseFlatYaml,
  semesterLabel,
};
