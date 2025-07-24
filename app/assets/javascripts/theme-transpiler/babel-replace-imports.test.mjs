/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import BabelReplaceImports from "./babel-replace-imports.js";

function compile(input) {
  return transformSync(input, {
    configFile: false,
    plugins: [BabelReplaceImports],
  }).code;
}

test("replaces imports with moduleBroker calls", () => {
  expect(
    compile(`
import concatClass from "discourse/helpers/concat-class";
import { default as renamedDefaultImport, namedImport, otherNamedImport as renamedImport } from "discourse/module-1";
  `)
  ).toMatchInlineSnapshot(`
    "const {
      default: concatClass
    } = await window.moduleBroker.lookup("discourse/helpers/concat-class");
    const {
      default: renamedDefaultImport,
      namedImport: namedImport,
      otherNamedImport: renamedImport
    } = await window.moduleBroker.lookup("discourse/module-1");"
  `);
});

test("handles namespace imports", () => {
  expect(
    compile(`
import * as MyModule from "discourse/module-1";
import defaultExport, * as MyModule2 from "discourse/module-2";
  `)
  ).toMatchInlineSnapshot(`
    "const MyModule = await window.moduleBroker.lookup("discourse/module-1");
    const {
      default: defaultExport
    } = await window.moduleBroker.lookup("discourse/module-2");
    const MyModule2 = await window.moduleBroker.lookup("discourse/module-2");"
  `);
});
