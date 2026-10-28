/* eslint-disable no-console */
// Applies mapping.json and definitions.json to core, bundled plugins and themes.
// Running it again gives the same result. After changing the mapping, reset the
// working tree to the commit before the last run, then run it again.
//
//   node css_variable_migration/apply.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import postcss from "postcss";
import scss from "postcss-scss";
import valueParser from "postcss-value-parser";
import * as prettier from "prettier";
import {
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

const { renames, merged, twins, definitions, errors } = loadMapping();
const pattern = namePattern(renames.keys());
const mergedPattern = namePattern(merged, "");
const twinPattern = namePattern(twins.keys(), "");
const report = [];
const results = new Map();
let twinReads = 0;

const definitionsByFile = new Map();
for (const definition of definitions) {
  definitionsByFile.set(definition.file, [
    ...(definitionsByFile.get(definition.file) ?? []),
    definition,
  ]);
}

if (errors.length === 0) {
  for (const file of listFiles()) {
    const original = readFileSync(join(ROOT, file), "utf8");
    const isStylesheet = /\.s?css$/.test(file);
    let text = original;

    if (
      isStylesheet &&
      file.startsWith(CORE_STYLESHEETS) &&
      mergedPattern.test(text)
    ) {
      text = removeMergedDefinitions(text, file);
    }

    text = text.replace(pattern, (name) => renames.get(name));

    if (twinPattern.test(text)) {
      const rewrite = rewriteTwinReads(text, twins);
      text = rewrite.text;
      twinReads += rewrite.rewritten;
    }

    if (isStylesheet) {
      try {
        text = tidy(text, file, definitionsByFile.get(file) ?? []);
      } catch (error) {
        // Broken stylesheets the mapping does not change, such as test fixtures, are left alone
        if (text !== original || definitionsByFile.has(file)) {
          errors.push(`${file}: ${error.message}`);
        }
      }
    }

    if (text !== original) {
      results.set(file, await format(file, original, text));
    }
  }
}

if (errors.length) {
  console.error("Nothing applied:");
  console.error(errors.map((error) => `  ${error}`).join("\n"));
  process.exit(1);
}

results.set(RENAMES_FILE, toJson(renames));
results.set(TWINS_FILE, toJson(twins));
for (const [file, text] of results) {
  writeFileSync(join(ROOT, file), text);
}

console.log(report.join("\n"));
console.log(
  `Applied ${renames.size + twins.size} mapping rows and ${definitions.length} definitions to ${results.size} files, rewriting ${twinReads} -rgb reads.`
);

function removeMergedDefinitions(text, file) {
  const root = scss.parse(text, { from: file });
  root.walkRules((rule) => {
    if (!isRootRule(rule)) {
      return;
    }
    rule.each((node) => {
      if (node.type === "decl" && merged.has(node.prop)) {
        report.push(
          `${file}:${node.source.start.line}: removed ${node.prop}, merged into ${renames.get(node.prop)}`
        );
        removeDeclaration(node);
      }
    });
  });
  return root.toString(scss);
}

function tidy(text, file, fileDefinitions) {
  const root = scss.parse(text, { from: file });

  root.walkDecls((decl) => {
    if (isSelfReference(decl)) {
      report.push(
        `${file}:${decl.source.start.line}: removed ${decl.prop}, it refers to itself`
      );
      removeDeclaration(decl);
    }
  });

  // Two old names renamed to one new name; the last declaration is the one in effect
  root.walkRules((rule) => {
    const seen = new Map();
    rule.each((node) => {
      if (node.type !== "decl" || !node.prop.startsWith("--")) {
        return;
      }
      const earlier = seen.get(node.prop);
      if (earlier) {
        report.push(
          `${file}:${earlier.source.start.line}: removed ${earlier.prop}, a later declaration in the same rule sets it`
        );
        removeDeclaration(earlier);
      }
      seen.set(node.prop, node);
    });
  });

  for (const definition of fileDefinitions) {
    define(root, file, definition);
  }

  return root.toString(scss);
}

function define(root, file, { name, value, after }) {
  const where = `definitions.json: ${name}`;
  const rule = root.nodes.find(isRootRule);
  if (!rule) {
    errors.push(`${where}: ${file} has no top-level :root rule`);
    return;
  }

  const existing = rule.nodes.find((n) => n.type === "decl" && n.prop === name);
  if (existing) {
    existing.value = value;
    return;
  }

  const decl = postcss.decl({ prop: name, value });
  if (!after) {
    rule.append(decl);
    return;
  }

  const anchor = rule.nodes.find((n) => n.type === "decl" && n.prop === after);
  if (!anchor) {
    errors.push(`${where}: ${after} is not declared in the :root of ${file}`);
    return;
  }
  (trailingComment(anchor) ?? anchor).after(decl);
}

function removeDeclaration(decl) {
  trailingComment(decl)?.remove();
  decl.remove();
}

function trailingComment(decl) {
  const next = decl.next();
  if (
    next?.type === "comment" &&
    next.source?.start.line === decl.source?.end.line
  ) {
    return next;
  }
}

function isSelfReference(decl) {
  if (!decl.prop.startsWith("--")) {
    return false;
  }
  const nodes = valueParser(decl.value).nodes.filter((n) => n.type !== "space");
  return (
    nodes.length === 1 &&
    nodes[0].type === "function" &&
    nodes[0].value === "var" &&
    nodes[0].nodes[0]?.value === decl.prop
  );
}

// Only rewrap files that were already formatted, so untouched lines stay as they are
async function format(file, original, text) {
  const path = join(ROOT, file);
  const { ignored, inferredParser } = await prettier.getFileInfo(path, {
    ignorePath: join(ROOT, ".prettierignore"),
  });
  if (ignored || !inferredParser || file.endsWith(".md")) {
    return text;
  }

  const options = { ...(await prettier.resolveConfig(path)), filepath: path };
  if (!(await prettier.check(original, options))) {
    return text;
  }
  return prettier.format(text, options);
}
