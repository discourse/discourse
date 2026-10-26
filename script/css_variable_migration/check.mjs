/* eslint-disable no-console */
// Checks that the working tree matches the mapping: the renamer list is in sync,
// no old name is left, and every definition is in place.
//
//   node script/css_variable_migration/check.mjs

import { readFileSync } from "node:fs";
import { join } from "node:path";
import scss from "postcss-scss";
import {
  isRootRule,
  listFiles,
  loadMapping,
  namePattern,
  RENAMES_FILE,
  renamesJson,
  ROOT,
} from "./mapping.mjs";

const { renames, definitions, errors } = loadMapping();
const warnings = [];

if (readFileSync(join(ROOT, RENAMES_FILE), "utf8") !== renamesJson(renames)) {
  errors.push(`${RENAMES_FILE} does not match mapping.csv`);
}

const pattern = namePattern(renames.keys());
const oldNames = [...renames.keys()];

for (const file of listFiles()) {
  const isStylesheet = /\.s?css$/.test(file);
  const lines = readFileSync(join(ROOT, file), "utf8").split("\n");
  lines.forEach((line, index) => {
    for (const [name] of line.matchAll(pattern)) {
      errors.push(`${file}:${index + 1}: ${name} is still used`);
    }
    if (!isStylesheet) {
      return;
    }
    for (const [built, prefix] of line.matchAll(/(--[\w-]*)#\{[^}]*\}/g)) {
      if (oldNames.some((name) => name.startsWith(prefix))) {
        warnings.push(`${file}:${index + 1}: ${built} may build an old name`);
      }
    }
  });
}

for (const { line, name, value, file } of definitions) {
  const root = scss.parse(readFileSync(join(ROOT, file), "utf8"));
  const decl = root.nodes
    .find(isRootRule)
    ?.nodes.find((n) => n.type === "decl" && n.prop === name);
  if (decl?.value !== value) {
    errors.push(`definitions.csv:${line}: ${name} is not ${value} in ${file}`);
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
  `Check passed: ${renames.size} mapping rows, ${definitions.length} definitions.`
);
