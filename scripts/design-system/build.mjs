// Generates the committed design-system SCSS from the DTCG token JSON.
//
//   common/design-system/base.json   -> base.scss    (:root { --d-base-* })
//   common/design-system/system.json -> system.scss  (:root { --d-system-*: var(--d-base-*) })
//
// The JSON is the source of truth (human / MCP / Figma editable); the SCSS is a
// committed build artifact, because Discourse compiles SCSS server-side and has
// no JSON->CSS hook. Run after editing the token JSON:
//
//   node scripts/design-system/build.mjs
//
// Rules:
//   - a token with a `com.discourse.dark` extension emits light-dark(<light>, <dark>)
//   - a value referencing another token ({d-base.color.gray.0}) emits
//     var(--d-base-color-gray-0), keeping the alias chain live in CSS
//
// No token-tooling dependency (the transform is small); prettier formats the
// output so the committed SCSS stays lint-clean.
import { readFileSync, writeFileSync } from "node:fs";
import prettier from "prettier";

const DIR = "app/assets/stylesheets/common/design-system";
const DARK_EXTENSION = "com.discourse.dark";

const GENERIC_FONT_FAMILIES = new Set([
  "serif",
  "sans-serif",
  "monospace",
  "cursive",
  "fantasy",
  "system-ui",
  "ui-serif",
  "ui-sans-serif",
  "ui-monospace",
  "ui-rounded",
  "math",
  "emoji",
  "fangsong",
]);

const usesReference = (value) =>
  typeof value === "string" && /\{[^}]+\}/.test(value);

const referencesToVars = (value) =>
  String(value).replace(
    /\{([^}]+)\}/g,
    (_, ref) => `var(--${ref.split(".").join("-")})`
  );

const shortenHex = (value) => {
  const match = /^#([0-9a-f])\1([0-9a-f])\2([0-9a-f])\3$/i.exec(value);
  return match ? `#${match[1]}${match[2]}${match[3]}` : value;
};

const quoteFontFamilies = (value) =>
  String(value)
    .split(",")
    .map((family) => family.trim())
    .map((family) =>
      GENERIC_FONT_FAMILIES.has(family.toLowerCase()) ? family : `"${family}"`
    )
    .join(", ");

const lightDark = (light, dark, transform = (v) => v) =>
  dark != null
    ? `light-dark(${transform(light)}, ${transform(dark)})`
    : transform(light);

function flatten(node, path = [], out = []) {
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith("$")) {
      continue;
    }
    const next = [...path, key];
    if (value && typeof value === "object" && "$value" in value) {
      out.push({ path: next, ...value });
    } else if (value && typeof value === "object") {
      flatten(value, next, out);
    }
  }
  return out;
}

function emit(tokens) {
  return tokens
    .map((token) => {
      const name = `--${token.path.join("-")}`;
      const value = token.$value;
      const type = token.$type;
      const dark = token.$extensions?.[DARK_EXTENSION];

      let css;
      if (usesReference(value)) {
        css = referencesToVars(value);
      } else if (type === "fontFamily") {
        css = quoteFontFamilies(value);
      } else if (type === "color") {
        css = lightDark(value, dark, shortenHex);
      } else {
        css = lightDark(value, dark);
      }
      return `  ${name}: ${css};`;
    })
    .join("\n");
}

for (const layer of ["base", "system"]) {
  const tokens = flatten(
    JSON.parse(readFileSync(`${DIR}/${layer}.json`, "utf8"))
  );
  const file = `${DIR}/${layer}.scss`;
  const raw = `:root {\n${emit(tokens)}\n}\n`;
  const config = await prettier.resolveConfig(file);
  writeFileSync(
    file,
    await prettier.format(raw, { ...config, filepath: file })
  );
}
