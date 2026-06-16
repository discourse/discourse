/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import BabelResolvePluginImports from "./babel-resolve-plugin-imports.js";

function compile(input) {
  return transformSync(input, {
    configFile: false,
    plugins: [BabelResolvePluginImports],
  }).code;
}

test("rewrites cross-plugin imports to the compatModules map", () => {
  expect(
    compile(`
import SharedThing, { somethingShared, other as renamed } from "discourse/plugins/other/lib/shared";
import * as Helpers from "discourse/plugins/other/lib/helpers";

SharedThing();
somethingShared(1);
renamed.property;
Helpers.doThing();
  `)
  ).toMatchInlineSnapshot(`
    "import _plugin_other from "discourse/plugins/other";
    (0, (_plugin_other["lib/shared"] || _plugin_other["lib/shared/index"]).default)();
    (0, (_plugin_other["lib/shared"] || _plugin_other["lib/shared/index"]).somethingShared)(1);
    (_plugin_other["lib/shared"] || _plugin_other["lib/shared/index"]).other.property;
    (_plugin_other["lib/helpers"] || _plugin_other["lib/helpers/index"]).doThing();"
  `);
});

test("de-dupes the default import per plugin", () => {
  expect(
    compile(`
import { a } from "discourse/plugins/other/lib/one";
import { b } from "discourse/plugins/other/lib/two";

a();
b();
  `)
  ).toMatchInlineSnapshot(`
    "import _plugin_other from "discourse/plugins/other";
    (0, (_plugin_other["lib/one"] || _plugin_other["lib/one/index"]).a)();
    (0, (_plugin_other["lib/two"] || _plugin_other["lib/two/index"]).b)();"
  `);
});

test("expands shorthand object properties inline", () => {
  expect(
    compile(`
import { foo, bar } from "discourse/plugins/other/lib/shared";

foo();
const obj = { bar };
  `)
  ).toMatchInlineSnapshot(`
    "import _plugin_other from "discourse/plugins/other";
    (0, (_plugin_other["lib/shared"] || _plugin_other["lib/shared/index"]).foo)();
    const obj = {
      bar: (_plugin_other["lib/shared"] || _plugin_other["lib/shared/index"]).bar
    };"
  `);
});

test("throws when a cross-plugin import is re-exported", () => {
  expect(() =>
    compile(`
import { foo } from "discourse/plugins/other/lib/shared";
export { foo };
  `)
  ).toThrow(/Re-exporting a cross-plugin import is not supported/);
});

test("leaves relative and core imports untouched", () => {
  expect(
    compile(`
import sibling from "./sibling";
import concatClass from "discourse/helpers/concat-class";
  `)
  ).toMatchInlineSnapshot(`
    "import sibling from "./sibling";
    import concatClass from "discourse/helpers/concat-class";"
  `);
});
