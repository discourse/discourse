import { module, test } from "qunit";
import {
  formatEntryWithErrorPath,
  parseConditionPath,
} from "discourse/lib/blocks/entry-formatter";

module("Unit | Blocks | entry-formatter", function () {
  module("parseConditionPath", function () {
    test("parses simple dot notation", function (assert) {
      assert.deepEqual(parseConditionPath("args.name"), ["args", "name"]);
    });

    test("parses bracket notation", function (assert) {
      assert.deepEqual(parseConditionPath("blocks[0]"), ["blocks", 0]);
    });

    test("parses mixed dot and bracket notation", function (assert) {
      assert.deepEqual(parseConditionPath("blocks[4].children[2].args.nme"), [
        "blocks",
        4,
        "children",
        2,
        "args",
        "nme",
      ]);
    });

    test("handles consecutive brackets", function (assert) {
      assert.deepEqual(parseConditionPath("conditions.any[0][1]"), [
        "conditions",
        "any",
        0,
        1,
      ]);
    });
  });

  module("formatEntryWithErrorPath", function () {
    test("marks existing key with error comment", function (assert) {
      const config = {
        block: "test",
        args: {
          name: "value",
        },
      };

      const result = formatEntryWithErrorPath(config, "args.name");

      assert.true(
        result.includes('name: "value", // <-- error here'),
        "error marker should appear on existing key"
      );
    });

    test("renders synthetic entry for non-existent key", function (assert) {
      const config = {
        block: "test",
        args: {
          name: "value",
        },
      };

      const result = formatEntryWithErrorPath(config, "args.nme");

      assert.true(
        result.includes("nme: <missing>, // <-- error here"),
        "should render synthetic entry for missing key 'nme'"
      );
      // Sibling keys are shown with their values (hybrid approach)
      assert.true(
        result.includes('name: "value"'),
        "should show sibling keys with their values"
      );
    });

    test("shows all keys with truncated values for non-path keys", function (assert) {
      const config = {
        block: "test",
        args: {
          errorKey: "bad",
        },
        conditions: { type: "route", name: "home" },
        children: [{ block: "child1" }, { block: "child2" }],
      };

      const result = formatEntryWithErrorPath(config, "args.errorKey");

      // Error key should have marker
      assert.true(
        result.includes('errorKey: "bad", // <-- error here'),
        "error key should have marker"
      );
      // Non-path keys should show truncated values
      assert.true(
        result.includes("conditions: { ... }"),
        "object keys not on path should show truncated"
      );
      assert.true(
        result.includes("children: [ 2 items ]"),
        "array keys not on path should show item count"
      );
      assert.true(
        result.includes('block: "test"'),
        "primitive keys not on path should show value"
      );
    });

    test("handles nested path with non-existent final segment", function (assert) {
      const config = {
        blocks: [
          {
            block: "group",
            args: {
              name: "test-group",
            },
          },
        ],
      };

      const result = formatEntryWithErrorPath(config, "blocks[0].args.nme");

      assert.true(
        result.includes("nme: <missing>, // <-- error here"),
        "should render synthetic entry at nested path"
      );
    });

    test("handles empty object parent for non-existent key", function (assert) {
      const config = {
        block: "test",
        args: {},
      };

      const result = formatEntryWithErrorPath(config, "args.missingKey");

      assert.true(
        result.includes("missingKey: <missing>, // <-- error here"),
        "should render synthetic entry in empty object"
      );
    });

    test("shows missing intermediate key when entire parent is absent", function (assert) {
      // When "args" is completely missing and error is "args.name"
      const config = {
        block: "group",
        children: [{ block: "child1" }, { block: "child2" }],
      };

      const result = formatEntryWithErrorPath(config, "args.name");

      // Should show args as missing with nested path to the error
      assert.true(result.includes("args:"), "should show missing 'args' key");
      assert.true(
        result.includes("// <-- missing"),
        "should indicate 'args' is missing"
      );
      assert.true(
        result.includes("name: <missing>"),
        "should show nested missing 'name' key"
      );
      assert.true(
        result.includes("// <-- error here"),
        "should show error marker on final key"
      );
    });

    test("does not add synthetic entry when key exists", function (assert) {
      const config = {
        args: {
          name: "value",
        },
      };

      const result = formatEntryWithErrorPath(config, "args.name");
      const invalidCount = (result.match(/<missing>/g) || []).length;

      assert.strictEqual(
        invalidCount,
        0,
        "should not add <missing> when key exists"
      );
    });

    test("marks array item with error comment when item itself is the error", function (assert) {
      const config = {
        type: "route",
        urls: ["TAG_PAGES", "/other/**"],
      };

      const result = formatEntryWithErrorPath(config, "urls[0]");

      assert.true(
        result.includes('"TAG_PAGES", // <-- error here'),
        "error marker should appear on array item when item itself is the error location"
      );
    });

    test("shows full nested path from root array to error", function (assert) {
      const config = [
        { block: "Block1", args: { name: "first" } },
        { block: "Block2", args: { name: "second" } },
        {
          block: "Block3",
          args: { name: "third" },
          children: [
            { block: "Child1", args: { title: "child1" } },
            { block: "Child2", args: { nme: "typo" } },
          ],
        },
        { block: "Block4", args: { name: "fourth" } },
      ];

      // Path starts with array index (no "blocks" prefix)
      const result = formatEntryWithErrorPath(
        config,
        "[2].children[1].args.nme"
      );

      // Should show ... for items before [2]
      assert.true(
        result.includes("..."),
        "should show ellipsis for skipped siblings"
      );

      // Should NOT show all items as { ... }
      const truncatedCount = (result.match(/\{ \.\.\. \}/g) || []).length;
      assert.true(
        truncatedCount < 4,
        `should not show all items as { ... }, got ${truncatedCount}`
      );

      // Should show the nested path to the error
      const showsBlock = result.includes("Block3") || result.includes("block:");
      assert.true(showsBlock, "should show the block on the error path");

      // Should show children array with nested structure
      assert.true(
        result.includes("children:"),
        "should show children key on path"
      );

      // Should show the error marker
      assert.true(
        result.includes("// <-- error here"),
        "should show error marker"
      );
    });
  });
});
