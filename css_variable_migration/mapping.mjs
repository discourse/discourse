import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import rewriteRgbTwins from "../frontend/asset-processor/rgb-twin-rewriter.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));

export const ROOT = join(HERE, "..");
export const RENAMES_FILE = "app/assets/stylesheets/variable-renames.json";
export const TWINS_FILE = "app/assets/stylesheets/variable-rgb-twins.json";
export const BORDERS_FILE =
  "app/assets/stylesheets/variable-border-splits.json";
export const BASE_LAYER_FILE =
  "app/assets/stylesheets/variable-base-layer.json";
export const CORE_STYLESHEETS = "app/assets/stylesheets/";

const TYPES = new Set([
  "rename",
  "merge",
  "rgb",
  "base",
  "drop",
  "border",
  "split",
]);
const ROLE =
  /^(text|icon|background|border|outline|shadow)(:(hovered|pressed|focused|disabled))?$/;
const RGB_CALL = /\brgba?\(/gi;
const NAME = /^--[\w-]+$/;
const COLOR = /^(#[\da-f]{3,8}|[a-z]+)$/i;

const EXTENSIONS = new Set([
  "scss",
  "css",
  "js",
  "gjs",
  "ts",
  "gts",
  "mjs",
  "cjs",
  "hbs",
  "rb",
  "erb",
  "svg",
  "md",
  "html",
  "yml",
]);

const EXCLUDED = [
  /^css_variable_migration\//,
  // Core's vendored stylesheets are themed with core's variables, so they are migrated too
  /^(?!app\/assets\/stylesheets\/)(.*\/)?vendor\//,
  /^public\//,
  // Translators own the other locales
  /(^|\/)config\/locales\/(?!.*\.en\.yml$)/,
  // Use old names on purpose, as examples and test cases
  /^frontend\/asset-processor\/postcss-variable-renamer\.test\.mjs$/,
  /^frontend\/asset-processor\/rgb-twin-rewriter(\.test)?\.mjs$/,
  /^frontend\/asset-processor\/border-shorthand-splitter(\.test)?\.mjs$/,
  /^frontend\/asset-processor\/css-variable-grammar\.test\.mjs$/,
];

export function loadMapping() {
  const errors = [];
  const mapping = readJson("mapping.json", errors);
  const renames = new Map();
  const merged = new Set();
  const twins = new Map();
  const base = new Set();
  const drops = new Map();
  const borders = new Map();
  const splits = new Map();

  for (const [type, entries] of Object.entries(mapping)) {
    if (!TYPES.has(type)) {
      errors.push(`mapping.json: unsupported type "${type}"`);
      continue;
    }
    for (const [oldName, entry] of Object.entries(entries)) {
      if (type === "split") {
        const roles = Object.fromEntries(
          Object.entries(entry ?? {}).filter(
            ([key]) => key !== "note" && key !== "open"
          )
        );
        for (const [role, target] of Object.entries(roles)) {
          if (!ROLE.test(role) || !(target === "keep" || NAME.test(target))) {
            errors.push(
              `mapping.json: ${oldName}: "${role}": "${target}" is not a role and a variable or "keep"`
            );
          }
        }
        splits.set(oldName, roles);
        continue;
      }
      if (type === "border") {
        const { width, color, style } = entry ?? {};
        if (!NAME.test(oldName) || !NAME.test(width) || !NAME.test(color)) {
          errors.push(
            `mapping.json: ${oldName}: a border entry names its width and color variables`
          );
        }
        borders.set(
          oldName,
          style ? { width, color, style } : { width, color }
        );
        continue;
      }
      if (type === "base" || type === "drop") {
        const successor = typeof entry === "string" ? null : entry?.to;
        if (
          !NAME.test(oldName) ||
          (successor !== null && !NAME.test(successor)) ||
          (type === "base" && successor !== null)
        ) {
          errors.push(
            `mapping.json: ${oldName}: a ${type} entry is a note${type === "drop" ? ", or a successor in `to`" : ""}`
          );
        }
        if (type === "base") {
          base.add(oldName);
        } else {
          drops.set(oldName, successor);
        }
        continue;
      }

      const newName = typeof entry === "string" ? entry : entry?.to;
      const isColor = type === "rgb" && COLOR.test(newName);
      if (!NAME.test(oldName) || !(NAME.test(newName) || isColor)) {
        errors.push(
          `mapping.json: ${oldName}: names must look like --some-name`
        );
      }
      if (type === "rgb") {
        twins.set(oldName, newName);
        continue;
      }
      renames.set(oldName, newName);
      if (type === "merge") {
        merged.add(oldName);
      }
    }
  }

  const isOld = (name) =>
    renames.has(name) ||
    twins.has(name) ||
    drops.has(name) ||
    borders.has(name);
  for (const newName of new Set([
    ...renames.values(),
    ...twins.values(),
    ...[...drops.values()].filter(Boolean),
    ...[...borders.values()].flatMap(({ width, color }) => [width, color]),
  ])) {
    if (isOld(newName)) {
      errors.push(`${newName} is both an old name and a new name`);
    }
  }

  const definitions = Object.entries(readJson("definitions.json", errors)).map(
    ([name, definition]) => ({ name, ...definition })
  );
  for (const { name, value, file } of definitions) {
    const where = `definitions.json: ${name}`;
    if (!NAME.test(name)) {
      errors.push(`${where}: names must look like --some-name`);
    }
    if (isOld(name)) {
      errors.push(`${where}: ${name} is an old name`);
    }
    if (typeof value !== "string") {
      errors.push(`${where}: value must be a string`);
    }
    if (!/\.s?css$/.test(file)) {
      errors.push(`${where}: ${file} is not a stylesheet`);
    } else if (!existsSync(join(ROOT, file))) {
      errors.push(`${where}: ${file} does not exist`);
    }
  }

  const overrides = readJson("overrides.json", errors);
  for (const [file, rules] of Object.entries(overrides)) {
    for (const [rule, props] of Object.entries(rules)) {
      for (const [prop, decision] of Object.entries(props)) {
        const targets =
          typeof decision === "string" ? [decision] : Object.values(decision);
        if (!targets.every((t) => t === "keep" || NAME.test(t))) {
          errors.push(
            `overrides.json: ${file} ${rule} ${prop}: use a variable or "keep"`
          );
        }
      }
    }
  }

  return {
    renames,
    merged,
    twins,
    base,
    drops,
    borders,
    splits,
    overrides,
    definitions,
    errors,
  };
}

export function baseLayer({ base, splits, twins }) {
  return new Map([
    ...[...base].map((name) => [name, "base"]),
    ...[...splits.keys()].map((name) => [name, "split"]),
    ...[...twins.keys()].map((name) => [name, "rgb"]),
  ]);
}

export function toJson(map) {
  return JSON.stringify(Object.fromEntries(map), null, 2) + "\n";
}

export function namePattern(names, flags = "g") {
  const alternatives = [...names].join("|") || "(?!)";
  return new RegExp(`(?<![\\w-])(?:${alternatives})(?![\\w-])`, flags);
}

export function listFiles() {
  return execFileSync("git", ["ls-files", "-z"], {
    cwd: ROOT,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  })
    .split("\0")
    .filter(
      (file) =>
        EXTENSIONS.has(file.split(".").pop()) &&
        !EXCLUDED.some((pattern) => pattern.test(file)) &&
        existsSync(join(ROOT, file))
    );
}

export function rewriteTwinReads(text, twins) {
  const twinObject = Object.fromEntries(twins);
  let result = "";
  let last = 0;
  let rewritten = 0;

  for (const match of text.matchAll(RGB_CALL)) {
    if (match.index < last) {
      continue;
    }
    const end = closingParen(text, match.index + match[0].length - 1);
    if (end === -1) {
      continue;
    }
    const call = text.slice(match.index, end + 1);
    const { value } = rewriteRgbTwins(call, twinObject);
    if (value !== call) {
      result += text.slice(last, match.index) + value;
      last = end + 1;
      rewritten++;
    }
  }

  return { text: result + text.slice(last), rewritten };
}

export function isRootRule(node) {
  return node.type === "rule" && node.selector.trim() === ":root";
}

function closingParen(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === "(") {
      depth++;
    } else if (text[i] === ")" && --depth === 0) {
      return i;
    }
  }
  return -1;
}

// JSON.parse keeps only the last of two equal keys, so look for them in the text
function readJson(name, errors) {
  const text = readFileSync(join(HERE, name), "utf8");
  const seen = new Set();
  for (const [, key] of text.matchAll(/"(--[\w-]+)"\s*:/g)) {
    if (seen.has(key)) {
      errors.push(`${name}: ${key} is listed more than once`);
    }
    seen.add(key);
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    errors.push(`${name}: ${error.message}`);
    return {};
  }
}
