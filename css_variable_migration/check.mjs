/* eslint-disable no-console */
// Checks that the working tree matches the mapping: the renamer and twin lists
// are in sync, no old name or dropped variable is read, no -rgb read is left
// that apply.mjs could rewrite, every definition is in place, and every base
// variable is still defined.
//
//   node css_variable_migration/check.mjs

import { readFileSync } from "node:fs";
import { join } from "node:path";
import scss from "postcss-scss";
import {
  BASE_LAYER_FILE,
  baseLayer,
  BORDERS_FILE,
  CORE_STYLESHEETS,
  isRootRule,
  listFiles,
  loadMapping,
  namePattern,
  RENAMES_FILE,
  rewriteTwinReads,
  ROOT,
  toJson,
  TWINS_FILE,
} from "./mapping.mjs";

const mapping = loadMapping();
const { renames, twins, base, drops, borders, splits, definitions, errors } =
  mapping;
const rows =
  renames.size +
  twins.size +
  base.size +
  drops.size +
  borders.size +
  splits.size;
const warnings = [];

for (const [file, map] of [
  [RENAMES_FILE, renames],
  [TWINS_FILE, twins],
  [BORDERS_FILE, borders],
  [BASE_LAYER_FILE, baseLayer(mapping)],
]) {
  if (readFileSync(join(ROOT, file), "utf8") !== toJson(map)) {
    errors.push(`${file} does not match mapping.json`);
  }
}

const pattern = namePattern([...renames.keys(), ...borders.keys()]);
const twinPattern = namePattern(twins.keys());
const dropPattern = namePattern(drops.keys());
const oldNames = [...renames.keys(), ...borders.keys()];
const definedInCore = new Set();

for (const file of listFiles()) {
  const isStylesheet = /\.s?css$/.test(file);
  const lines = readFileSync(join(ROOT, file), "utf8").split("\n");
  lines.forEach((line, index) => {
    for (const [name] of line.matchAll(pattern)) {
      errors.push(`${file}:${index + 1}: ${name} is still used`);
    }
    for (const match of line.matchAll(dropPattern)) {
      const rest = line.slice(match.index + match[0].length);
      if (/^\s*:/.test(rest)) {
        warnings.push(
          `${file}:${index + 1}: ${match[0]} is dropped but still set`
        );
      } else {
        errors.push(
          `${file}:${index + 1}: ${match[0]} is dropped but still read`
        );
      }
    }
    if (rewriteTwinReads(line, twins).rewritten) {
      errors.push(`${file}:${index + 1}: an -rgb read can still be rewritten`);
    } else {
      for (const match of line.matchAll(twinPattern)) {
        const rest = line.slice(match.index + match[0].length);
        if (!/^\s*:/.test(rest)) {
          warnings.push(`${file}:${index + 1}: ${match[0]} is still read`);
        }
      }
    }
    if (!isStylesheet) {
      return;
    }
    if (file.startsWith(CORE_STYLESHEETS)) {
      for (const [, name] of line.matchAll(/^\s*(--[\w-]+)\s*:/g)) {
        definedInCore.add(name);
      }
    }
    for (const [built, prefix] of line.matchAll(/(--[\w-]*)#\{[^}]*\}/g)) {
      if (oldNames.some((name) => name.startsWith(prefix))) {
        warnings.push(`${file}:${index + 1}: ${built} may build an old name`);
      }
    }
  });
}

for (const name of base) {
  if (!definedInCore.has(name)) {
    warnings.push(`${name} is a base variable but core does not define it`);
  }
}

for (const { name, value, file } of definitions) {
  const root = scss.parse(readFileSync(join(ROOT, file), "utf8"));
  const decl = root.nodes
    .find(isRootRule)
    ?.nodes.find((n) => n.type === "decl" && n.prop === name);
  if (decl?.value !== value) {
    errors.push(`definitions.json: ${name} is not ${value} in ${file}`);
  }
}

if (warnings.length) {
  console.log("Check by hand:");
  console.log(warnings.map((warning) => `  ${warning}`).join("\n"));
}
if (errors.length) {
  console.error("Check failed:");
  console.error(errors.map((error) => `  ${error}`).join("\n"));
  process.exit(1);
}
console.log(
  `Check passed: ${rows} mapping rows, ${definitions.length} definitions.`
);
