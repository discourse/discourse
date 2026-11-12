/* eslint-disable qunit/require-expect */
import postcss from "postcss";
import { expect, test } from "vitest";
import renames from "../../app/assets/stylesheets/variable-renames.json";
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
