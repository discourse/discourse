/* eslint-disable no-console */
// Applies mapping.json and definitions.json to core, bundled plugins and themes.
// Running it again gives the same result. After changing the mapping, reset the
// working tree to the commit before the last run, then run it again.
//
//   node css_variable_migration/apply.mjs

import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import postcss from "postcss";
import scss from "postcss-scss";
import valueParser from "postcss-value-parser";
import * as prettier from "prettier";
import {
  splitBorderReads,
  splitBorderSetter,
} from "../frontend/asset-processor/border-shorthand-splitter.mjs";
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
const {
  renames,
  merged,
  twins,
  drops,
  borders,
  splits,
  overrides,
  definitions,
  errors,
} = mapping;
const borderSplits = Object.fromEntries(borders);
const splitNames = [...splits.keys()];
const splitTargets = new Set(
  [...splits.values()].flatMap((roles) =>
    Object.values(roles).filter((target) => target !== "keep")
  )
);
const SCOPE_ROOT = /^(:root|html)$/;
const TEXT_PROPS = new Set([
  "color",
  "-webkit-text-fill-color",
  "caret-color",
  "text-decoration",
  "text-decoration-color",
]);
const undecided = {};
const usedOverrides = new Set();
let splitReads = 0;
const pattern = namePattern(renames.keys());
const removed = new Set([...merged, ...drops.keys()]);
const removedPattern = namePattern(removed, "");
const successors = new Map([...drops].filter(([, successor]) => successor));
const successorPattern = namePattern(successors.keys());
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
      removedPattern.test(text)
    ) {
      text = removeDefinitions(text, file);
    }

    text = text.replace(pattern, (name) => renames.get(name));

    // Only reads move to a successor; setters stay, so they cannot restyle what the successor controls
    text = text.replace(successorPattern, (name, offset, whole) =>
      /^\s*:/.test(whole.slice(offset + name.length))
        ? name
        : successors.get(name)
    );

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
results.set(BORDERS_FILE, toJson(borders));
results.set(BASE_LAYER_FILE, toJson(baseLayer(mapping)));
const ruby = [...results.keys()].filter((file) => file.endsWith(".rb"));
const unformatted = unformattedRuby(ruby);
const formattedRuby = ruby.filter((file) => !unformatted.has(file));
for (const [file, text] of results) {
  writeFileSync(join(ROOT, file), text);
}
if (formattedRuby.length) {
  stree("write", formattedRuby);
}

for (const [file, rules] of Object.entries(overrides)) {
  for (const [rule, props] of Object.entries(rules)) {
    for (const prop of Object.keys(props)) {
      if (!usedOverrides.has(`${file}\t${rule}\t${prop}`)) {
        report.push(`overrides.json: ${file} ${rule} ${prop} matches no use`);
      }
    }
  }
}

const undecidedCounts = new Map();
for (const rules of Object.values(undecided)) {
  for (const props of Object.values(rules)) {
    for (const names of Object.values(props)) {
      for (const name of names) {
        undecidedCounts.set(name, (undecidedCounts.get(name) ?? 0) + 1);
      }
    }
  }
}
const undecidedFile = join(ROOT, "tmp/css_variable_migration/undecided.json");
mkdirSync(join(ROOT, "tmp/css_variable_migration"), { recursive: true });
writeFileSync(undecidedFile, JSON.stringify(undecided, null, 2) + "\n");

console.log(report.join("\n"));
if (undecidedCounts.size) {
  console.log(
    `Undecided split uses, left on the base variable (${undecidedFile}):\n` +
      [...undecidedCounts]
        .sort((a, b) => b[1] - a[1])
        .map(([name, count]) => `  ${name}: ${count}`)
        .join("\n")
  );
}
console.log(
  `Applied ${renames.size + twins.size + borders.size + splits.size} mapping rows and ${definitions.length} definitions to ${results.size} files, rewriting ${twinReads} -rgb reads and moving ${splitReads} split uses.`
);

function removeDefinitions(text, file) {
  const root = scss.parse(text, { from: file });
  root.walkRules((rule) => {
    if (!isRootRule(rule)) {
      return;
    }
    rule.each((node) => {
      if (node.type === "decl" && removed.has(node.prop)) {
        const reason = merged.has(node.prop)
          ? `merged into ${renames.get(node.prop)}`
          : "dropped";
        report.push(
          `${file}:${node.source.start.line}: removed ${node.prop}, ${reason}`
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
    if (Object.hasOwn(borderSplits, decl.prop)) {
      splitSetter(decl, file);
    } else {
      decl.value = splitBorderReads(decl.value, borderSplits).value;
    }
  });
  root.walkAtRules((atRule) => {
    atRule.params = splitBorderReads(atRule.params, borderSplits).value;
  });

  setSplitTargetsInScope(root, file);
  root.walkDecls((decl) => moveSplitReads(decl, file));
  root.walkAtRules((atRule) => {
    for (const name of splitNames) {
      if (atRule.params.includes(`var(${name}`)) {
        noteUndecided(file, rulePath(atRule.parent), `@${atRule.name}`, name);
      }
    }
  });

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

// A split variable set inside a selector no longer reaches its targets, which are
// computed on :root, so the targets are set from it in the same rule
function setSplitTargetsInScope(root, file) {
  root.walkRules((rule) => {
    if (SCOPE_ROOT.test(rule.selector.trim())) {
      return;
    }
    rule.each((decl) => {
      if (decl.type !== "decl" || !splits.has(decl.prop)) {
        return;
      }
      let anchor = trailingComment(decl) ?? decl;
      for (const target of new Set(Object.values(splits.get(decl.prop)))) {
        if (
          target === "keep" ||
          rule.some((n) => n.type === "decl" && n.prop === target)
        ) {
          continue;
        }
        const added = postcss.decl({
          prop: target,
          value: `var(${decl.prop})`,
          important: decl.important,
        });
        anchor.after(added);
        anchor = added;
        report.push(
          `${file}:${decl.source.start.line}: set ${target} from ${decl.prop} in ${rule.selector}`
        );
      }
    });
  });
}

function moveSplitReads(decl, file) {
  if (
    !splitNames.some((name) => decl.value.includes(name)) ||
    decl.prop.startsWith("--d-sys-") ||
    splitTargets.has(decl.prop) ||
    splits.has(decl.prop)
  ) {
    return;
  }

  const path = rulePath(decl.parent);
  const override = overrides[file]?.[path]?.[decl.prop];
  if (override !== undefined) {
    usedOverrides.add(`${file}\t${path}\t${decl.prop}`);
  }
  const role = roleOf(decl);

  const parsed = valueParser(decl.value);
  let changed = false;
  parsed.walk((node) => {
    const name =
      node.type === "function" && node.value === "var" && node.nodes[0]?.value;
    if (!splits.has(name)) {
      return;
    }
    const roles = splits.get(name);
    const target =
      (typeof override === "string" ? override : override?.[name]) ??
      (role && (roles[`${role.name}:${role.state}`] ?? roles[role.name]));
    if (!target) {
      noteUndecided(file, path, decl.prop, name);
    } else if (target !== "keep") {
      node.nodes[0].value = target;
      changed = true;
      splitReads++;
    }
  });
  if (changed) {
    decl.value = parsed.toString();
  }
}

// The role comes from a component token's own name, or from the CSS property and the selectors around it
function roleOf(decl) {
  const prop = decl.prop.toLowerCase();
  if (prop.startsWith("$")) {
    return null;
  }
  if (prop.startsWith("--")) {
    const match = prop.match(
      /^--d-comp-.+?-color-(text|icon|background|border|outline)(?:-|$)/
    );
    const state = prop.match(/-(hovered|pressed|focused|disabled)$/)?.[1];
    return match && { name: match[1], state };
  }

  const selectors = [];
  for (let n = decl.parent; n && n.type !== "root"; n = n.parent) {
    if (n.type === "rule") {
      selectors.push(n.selector);
    }
  }
  const chain = selectors.join(" ");
  const state = /:hover/.test(chain)
    ? "hovered"
    : /:active/.test(chain)
      ? "pressed"
      : /:focus/.test(chain)
        ? "focused"
        : /:disabled|\[disabled\]|\.disabled\b|--disabled\b/.test(chain)
          ? "disabled"
          : undefined;
  const icon = /\.d-icon|\.fa\b|\.svg-icon|(^|[\s>+~(,])svg\b/.test(chain);

  let name;
  if (prop === "fill" || prop === "stroke") {
    name = "icon";
  } else if (TEXT_PROPS.has(prop)) {
    name = icon ? "icon" : "text";
  } else if (prop.startsWith("background")) {
    name = "background";
  } else if (prop.startsWith("border")) {
    name = "border";
  } else if (prop.startsWith("outline")) {
    name = "outline";
  } else if (prop.endsWith("shadow")) {
    name = "shadow";
  } else {
    return null;
  }
  return { name, state };
}

function rulePath(node) {
  const parts = [];
  for (let n = node; n && n.type !== "root"; n = n.parent) {
    parts.unshift(
      n.type === "rule"
        ? n.selector.replace(/\s+/g, " ").trim()
        : `@${n.name} ${n.params}`.trim()
    );
  }
  return parts.join(" >> ");
}

function noteUndecided(file, path, prop, name) {
  const rules = (undecided[file] ??= {});
  const props = (rules[path] ??= {});
  props[prop] = [...new Set([...(props[prop] ?? []), name])];
}

function splitSetter(decl, file) {
  const where = `${file}:${decl.source.start.line}`;
  const split = splitBorderSetter(decl.prop, decl.value, borderSplits);
  if (!split) {
    errors.push(`${where}: cannot split ${decl.prop}: ${decl.value}`);
    return;
  }
  for (const { prop, value } of split.declarations) {
    decl.cloneBefore({ prop, value });
  }
  if (split.lost.length) {
    report.push(`${where}: split ${decl.prop} without its ${split.lost}`);
  }
  decl.remove();
}

function define(root, file, { name, value, after }) {
  let rule = root.nodes.find(isRootRule);
  if (!rule) {
    rule = postcss.rule({ selector: ":root" });
    const imports = root.nodes.filter(
      (n) =>
        n.type === "atrule" && ["use", "forward", "import"].includes(n.name)
    );
    if (imports.length) {
      imports.at(-1).after(rule);
      rule.raws.before = "\n\n";
    } else {
      root.prepend(rule);
    }
    if (rule.next()) {
      rule.next().raws.before = "\n\n";
    }
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
    const where = `definitions.json: ${name}`;
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

function stree(command, files) {
  return spawnSync("bundle", ["exec", "stree", command, ...files], {
    cwd: ROOT,
    encoding: "utf8",
  });
}

function unformattedRuby(files) {
  if (!files.length) {
    return new Set();
  }
  const { stdout, stderr } = stree("check", files);
  return new Set(
    [...`${stdout}${stderr}`.matchAll(/^\[warn\] (.+)$/gm)].map((m) => m[1])
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
