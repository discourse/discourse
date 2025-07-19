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

test("foobar", () => {
  expect(
    compile(`
import concatClass from "discourse/helpers/concat-class";
  `)
  ).toMatchInlineSnapshot(`
    "const {
      default: concatClass
    } = await window.moduleBroker.lookup("discourse/helpers/concat-class");"
  `);

  // TODO/NOTE: when running discourse-tag-group-topic-filter tests,
  // `import FilterTag from "../../discourse/components/filter-tag";`
  // in a test file (test/acceptance/filter-tag-test.gjs) is converted to:
  // `const {default: FilterTag} = await window.moduleBroker.lookup("discourse/components/filter-tag");`
  // But the issue isn't in this transform. Something else in the rollup pipeline
  // changes the import before it get here.
  expect(
    compile(`
import localComponent from "../../discourse/components/local-component";
  `)
  ).toMatchInlineSnapshot(
    `"import localComponent from "../../discourse/components/local-component";"`
  );
});
