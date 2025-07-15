/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import BabelCrossThemeImport from "./babel-cross-theme-import.js";

test("foobar", () => {
  const input = `
import { HELLO_TWO } from "discourse/theme-2/discourse/initializers/init-two";
console.log(HELLO_TWO);
  `;
  const output = transformSync(input, {
    configFile: false,
    plugins: [BabelCrossThemeImport],
  }).code;
  expect(output).toMatchInlineSnapshot(`
    "import DiscourseAutoImportMod0 from "discourse/theme-2";
    console.log(DiscourseAutoImportMod0["discourse/initializers/init-two"].HELLO_TWO);"
  `);
});
