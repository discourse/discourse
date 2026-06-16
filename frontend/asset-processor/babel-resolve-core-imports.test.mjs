/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import BabelResolveCoreImports from "./babel-resolve-core-imports.js";

function compile(input) {
  return transformSync(input, {
    configFile: false,
    plugins: [BabelResolveCoreImports],
  }).code;
}

test("destructures core imports from moduleBroker", () => {
  expect(
    compile(`
import concatClass from "discourse/helpers/concat-class";
import { default as renamedDefaultImport, namedImport, otherNamedImport as renamedImport } from "discourse/module-1";
  `)
  ).toMatchInlineSnapshot(`
    "const {
      default: concatClass
    } = window.moduleBroker.lookup("discourse/helpers/concat-class");
    const {
      default: renamedDefaultImport,
      namedImport: namedImport,
      otherNamedImport: renamedImport
    } = window.moduleBroker.lookup("discourse/module-1");"
  `);
});

test("handles core namespace imports", () => {
  expect(
    compile(`
import * as MyModule from "discourse/module-1";
import defaultExport, * as MyModule2 from "discourse/module-2";
  `)
  ).toMatchInlineSnapshot(`
    "const MyModule = window.moduleBroker.lookup("discourse/module-1");
    const {
      default: defaultExport
    } = window.moduleBroker.lookup("discourse/module-2");
    const MyModule2 = window.moduleBroker.lookup("discourse/module-2");"
  `);
});

test("leaves relative, virtual, theme and plugin imports untouched", () => {
  expect(
    compile(`
import sibling from "./sibling";
import { settings } from "discourse/theme-12/settings";
import Thing from "discourse/plugins/other/lib/thing";
  `)
  ).toMatchInlineSnapshot(`
    "import sibling from "./sibling";
    import { settings } from "discourse/theme-12/settings";
    import Thing from "discourse/plugins/other/lib/thing";"
  `);
});
