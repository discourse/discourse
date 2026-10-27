import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import rewriteRgbTwins from "../../frontend/asset-processor/rgb-twin-rewriter.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));

export const ROOT = join(HERE, "../..");
export const RENAMES_FILE = "app/assets/stylesheets/variable-renames.json";
export const TWINS_FILE = "app/assets/stylesheets/variable-rgb-twins.json";
export const CORE_STYLESHEETS = "app/assets/stylesheets/";

const TYPES = new Set(["rename", "merge", "rgb"]);
const RGB_CALL = /\brgba?\(/gi;
const NAME = /^--[\w-]+$/;

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
]);

const EXCLUDED = [
  /^script\/css_variable_migration\//,
  /(^|\/)vendor\//,
  /^public\//,
  // Use old names on purpose, as examples and test cases
  /^frontend\/asset-processor\/postcss-variable-renamer\.test\.mjs$/,
  /^frontend\/asset-processor\/rgb-twin-rewriter(\.test)?\.mjs$/,
];

export function loadMapping() {
  const rows = readCsv("mapping.csv");
  const definitions = readCsv("definitions.csv");
  const renames = new Map();
  const merged = new Set();
  const twins = new Map();
  const errors = [];

  for (const row of rows) {
    const where = `mapping.csv:${row.line}`;
    if (!TYPES.has(row.type)) {
      errors.push(`${where}: unsupported type "${row.type}"`);
    }
    if (!NAME.test(row.old_name) || !NAME.test(row.new_name)) {
      errors.push(`${where}: names must look like --some-name`);
    }
    if (renames.has(row.old_name) || twins.has(row.old_name)) {
      errors.push(`${where}: ${row.old_name} is mapped more than once`);
    }
    if (row.type === "rgb") {
      twins.set(row.old_name, row.new_name);
      continue;
    }
    renames.set(row.old_name, row.new_name);
    if (row.type === "merge") {
      merged.add(row.old_name);
    }
  }

  for (const newName of new Set([...renames.values(), ...twins.values()])) {
    if (renames.has(newName) || twins.has(newName)) {
      errors.push(`${newName} is both an old name and a new name`);
    }
  }

  const defined = new Set();
  for (const definition of definitions) {
    const where = `definitions.csv:${definition.line}`;
    if (!NAME.test(definition.name)) {
      errors.push(`${where}: names must look like --some-name`);
    }
    if (renames.has(definition.name) || twins.has(definition.name)) {
      errors.push(`${where}: ${definition.name} is an old name`);
    }
    if (defined.has(definition.name)) {
      errors.push(`${where}: ${definition.name} is defined more than once`);
    }
    if (!/\.s?css$/.test(definition.file)) {
      errors.push(`${where}: ${definition.file} is not a stylesheet`);
    } else if (!existsSync(join(ROOT, definition.file))) {
      errors.push(`${where}: ${definition.file} does not exist`);
    }
    defined.add(definition.name);
  }

  return { renames, merged, twins, definitions, errors };
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

function readCsv(name) {
  const [header, ...rows] = parseCsv(readFileSync(join(HERE, name), "utf8"));
  return rows.map((cells, index) => ({
    line: index + 2,
    ...Object.fromEntries(header.map((key, i) => [key, cells[i] ?? ""])),
  }));
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;

  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      rows.push([...row, field]);
      row = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }
  if (field || row.length) {
    rows.push([...row, field]);
  }

  return rows;
}
