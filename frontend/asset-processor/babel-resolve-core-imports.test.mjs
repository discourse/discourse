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

test("waits for core modal imports before evaluating plugin code", async () => {
  class Modal {}
  const calls = [];
  const run = new (Object.getPrototypeOf(async function () {}).constructor)(
    "window",
    compile(`
      import Modal from "discourse/components/modal/flag";
      export default Modal;
    `).replace("export default Modal;", "return Modal;")
  );

  const modal = await run({
    moduleBroker: {
      async load(name) {
        calls.push(name);
        return { default: Modal };
      },
    },
  });

  expect(calls).toEqual(["discourse/components/modal/flag"]);
  expect(modal).toBe(Modal);
});

test("loads optional modal namespace and side-effect imports", () => {
  expect(
    compile(`
      import * as Modal from "discourse/components/modal/flag" with { discourseImport: "optional" };
      import "discourse/components/modal/move-to-topic";
    `)
  ).toMatchInlineSnapshot(`
    "const Modal = await window.moduleBroker.load("discourse/components/modal/flag", true);
    await window.moduleBroker.load("discourse/components/modal/move-to-topic");"
  `);
});

test("marks optional core imports with a second lookup argument", () => {
  expect(
    compile(`
import concatClass from "discourse/helpers/concat-class" with { discourseImport: "optional" };
import * as MyModule from "discourse/module-1" with { discourseImport: "optional" };
  `)
  ).toMatchInlineSnapshot(`
    "const {
      default: concatClass
    } = window.moduleBroker.lookup("discourse/helpers/concat-class", true);
    const MyModule = window.moduleBroker.lookup("discourse/module-1", true);"
  `);
});

test('`discourseImport: "required"` keeps the default required lookup', () => {
  expect(
    compile(`
import concatClass from "discourse/helpers/concat-class" with { discourseImport: "required" };
  `)
  ).toMatchInlineSnapshot(`
    "const {
      default: concatClass
    } = window.moduleBroker.lookup("discourse/helpers/concat-class");"
  `);
});

test("throws on an unknown `discourseImport` value", () => {
  expect(() =>
    compile(`
import concatClass from "discourse/helpers/concat-class" with { discourseImport: "maybe" };
  `)
  ).toThrow(/Invalid `discourseImport` import attribute "maybe"/);
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

test("loads dynamic core modal imports through the broker", () => {
  expect(
    compile('modal.show(import("discourse/components/modal/flag"));')
  ).toBe(
    'modal.show(window.moduleBroker.load("discourse/components/modal/flag"));'
  );
});
