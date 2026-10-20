/* eslint-disable qunit/require-expect */
import postcss from "postcss";
import { expect, test } from "vitest";
import renames from "../../app/assets/stylesheets/variable-renames.json";
import rgbTwins from "../../app/assets/stylesheets/variable-rgb-twins.json";
import postcssVariableRenamer from "./postcss-variable-renamer.js";

const testMap = { "--old-name": "--new-name" };

function process(css) {
  return postcss([postcssVariableRenamer(testMap)]).process(css, {
    from: undefined,
  }).css;
}

test("rewrites declarations of a renamed variable", () => {
  expect(process(":root { --old-name: red; }")).toBe(
    ":root { --new-name: red; /* automatically renamed --old-name to --new-name */ }"
  );
});

test("rewrites var() references", () => {
  expect(process("a { color: var(--old-name); }")).toBe(
    "a { color: var(--new-name); /* automatically renamed --old-name to --new-name */ }"
  );
});

test("rewrites references inside fallbacks", () => {
  expect(process("a { color: var(--brand, var(--old-name)); }")).toBe(
    "a { color: var(--brand, var(--new-name)); /* automatically renamed --old-name to --new-name */ }"
  );
});

test("preserves fallback of a renamed reference", () => {
  expect(process("a { color: var(--old-name, blue); }")).toBe(
    "a { color: var(--new-name, blue); /* automatically renamed --old-name to --new-name */ }"
  );
});

test("leaves longer names alone", () => {
  const css = "a { color: var(--old-name-hover); }";
  expect(process(css)).toBe(css);
});

test("leaves names with a prefix alone", () => {
  const css = "a { color: var(--theme--old-name); }";
  expect(process(css)).toBe(css);
});

test("adds one comment when a declaration sets and reads the same old name", () => {
  expect(process(":root { --old-name: var(--old-name, red); }")).toBe(
    ":root { --new-name: var(--new-name, red); /* automatically renamed --old-name to --new-name */ }"
  );
});

function rewriteTwins(css) {
  const twins = { "--brand-rgb": "--brand" };
  return postcss([postcssVariableRenamer({}, twins)]).process(css, {
    from: undefined,
  }).css;
}

test("rewrites an rgb() twin with alpha to color-mix()", () => {
  expect(rewriteTwins("a { color: rgb(var(--brand-rgb), 0.9); }")).toBe(
    "a { color: color-mix(in srgb, var(--brand) 90%, transparent); /* automatically rewrote --brand-rgb to color-mix() on --brand */ }"
  );
});

test("rewrites rgba() and slash syntax", () => {
  expect(rewriteTwins("a { color: rgba(var(--brand-rgb), 0.25); }")).toContain(
    "color-mix(in srgb, var(--brand) 25%, transparent)"
  );
  expect(rewriteTwins("a { color: rgb(var(--brand-rgb) / 50%); }")).toContain(
    "color-mix(in srgb, var(--brand) 50%, transparent)"
  );
});

test("rewrites a variable alpha with calc()", () => {
  expect(
    rewriteTwins("a { color: rgb(var(--brand-rgb), var(--alpha)); }")
  ).toContain(
    "color-mix(in srgb, var(--brand) calc(var(--alpha) * 100%), transparent)"
  );
});

test("rewrites an rgb() twin without alpha to the color", () => {
  expect(rewriteTwins("a { color: rgb(var(--brand-rgb)); }")).toContain(
    "color: var(--brand);"
  );
});

test("rewrites twins inside larger values", () => {
  expect(
    rewriteTwins("a { box-shadow: 0 1px 2px rgb(var(--brand-rgb), 0.1); }")
  ).toContain(
    "box-shadow: 0 1px 2px color-mix(in srgb, var(--brand) 10%, transparent);"
  );
});

test("leaves a twin with a fallback alone", () => {
  const css = "a { color: rgb(var(--brand-rgb, 0, 0, 0), 0.5); }";
  expect(rewriteTwins(css)).toBe(css);
});

test("twin map points at custom property names", () => {
  for (const [twin, color] of Object.entries(rgbTwins)) {
    expect(twin).toMatch(/^--[\w-]+-rgb$/);
    expect(color).toMatch(/^--[\w-]+$/);
  }
});

test("leaves untouched declarations alone", () => {
  const css = "a { color: var(--primary); }";
  expect(process(css)).toBe(css);
});

test("leaves string contents alone", () => {
  const css = 'a::before { content: "--old-name"; }';
  expect(process(css)).toBe(css);
});

test("map has no chains", () => {
  const oldNames = new Set(Object.keys(renames));
  for (const newName of Object.values(renames)) {
    expect(oldNames).not.toContain(newName);
  }
});

test("map only contains custom property names", () => {
  for (const [oldName, newName] of Object.entries(renames)) {
    expect(oldName).toMatch(/^--[\w-]+$/);
    expect(newName).toMatch(/^--[\w-]+$/);
  }
});
