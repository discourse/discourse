/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import AddThemeGlobals from "./add-theme-globals.js";

function compile(input) {
  return transformSync(input, {
    configFile: false,
    plugins: [AddThemeGlobals],
  }).code;
}

test("adds imports automatically", () => {
  expect(
    compile(`
console.log(settings, themePrefix);
  `)
  ).toMatchInlineSnapshot(`
    "import { themePrefix, settings } from "virtual:theme";
    console.log(settings, themePrefix);"
  `);
});

test("throws error if settings or themePrefix are defined locally", () => {
  expect(() =>
    compile(`
const settings = {};
console.log(settings);
  `)
  ).toThrowErrorMatchingInlineSnapshot(
    `[Error: unknown file: \`settings\` is already defined. Unable to add import.]`
  );

  expect(() =>
    compile(`
const themePrefix = "foo";
console.log(themePrefix);
  `)
  ).toThrowErrorMatchingInlineSnapshot(
    `[Error: unknown file: \`themePrefix\` is already defined. Unable to add import.]`
  );
});

test("works if settings and themePrefix are already imported", () => {
  expect(
    compile(`
import { themePrefix, settings } from "virtual:theme";
console.log(settings, themePrefix);
  `)
  ).toMatchInlineSnapshot(`
    "import { themePrefix, settings } from "virtual:theme";
    console.log(settings, themePrefix);"
  `);
});

test("throws error if settings or themePrefix are already imported from the wrong place", () => {
  expect(() =>
    compile(`
import { themePrefix } from "foo";
console.log(themePrefix);
  `)
  ).toThrowErrorMatchingInlineSnapshot(
    `[Error: unknown file: \`themePrefix\` is already imported. Unable to add import from \`virtual:theme\`.]`
  );

  expect(() =>
    compile(`
import { settings } from "foo";
console.log(settings);
  `)
  ).toThrowErrorMatchingInlineSnapshot(
    `[Error: unknown file: \`settings\` is already imported. Unable to add import from \`virtual:theme\`.]`
  );
});
