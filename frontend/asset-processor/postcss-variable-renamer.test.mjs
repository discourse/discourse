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

test("removes a declaration that a merge turns into a reference to itself", () => {
  const merge = { "--old-a": "--merged", "--old-b": "--merged" };
  const css = postcss([postcssVariableRenamer(merge)]).process(
    ":root { --old-a: var(--old-b); }",
    { from: undefined }
  ).css;
  expect(css).toBe(
    ":root { /* automatically removed --old-a: var(--old-b), both names now refer to --merged */ }"
  );
});

test("keeps a merge when the value is more than the reference", () => {
  const merge = { "--old-a": "--merged", "--old-b": "--merged" };
  const css = postcss([postcssVariableRenamer(merge)]).process(
    ":root { --old-a: calc(var(--old-b) * 2); }",
    { from: undefined }
  ).css;
  expect(css).toBe(
    ":root { --merged: calc(var(--merged) * 2); /* automatically renamed --old-a to --merged, --old-b to --merged */ }"
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
