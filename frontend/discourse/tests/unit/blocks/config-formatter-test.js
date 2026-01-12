import { module, test } from "qunit";
import {
  formatConfigWithErrorPath,
  parseConditionPath,
} from "discourse/lib/blocks/config-formatter";

module("Unit | Blocks | config-formatter", function () {
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

  module("formatConfigWithErrorPath", function () {
    test("marks existing key with error comment", function (assert) {
      const config = {
        block: "test",
        args: {
          name: "value",
        },
      };

      const result = formatConfigWithErrorPath(config, "args.name");

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

      const result = formatConfigWithErrorPath(config, "args.nme");

      assert.true(
        result.includes("nme: <invalid>, // <-- error here"),
        "should render synthetic entry for missing key 'nme'"
      );
      // Keys not on the error path are shown as "..." by design
      assert.true(
        result.includes("..."),
        "should show ellipsis for existing keys not on error path"
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

      const result = formatConfigWithErrorPath(config, "blocks[0].args.nme");

      assert.true(
        result.includes("nme: <invalid>, // <-- error here"),
        "should render synthetic entry at nested path"
      );
    });

    test("handles empty object parent for non-existent key", function (assert) {
      const config = {
        block: "test",
        args: {},
      };

      const result = formatConfigWithErrorPath(config, "args.missingKey");

      assert.true(
        result.includes("missingKey: <invalid>, // <-- error here"),
        "should render synthetic entry in empty object"
      );
    });

    test("does not add synthetic entry when key exists", function (assert) {
      const config = {
        args: {
          name: "value",
        },
      };

      const result = formatConfigWithErrorPath(config, "args.name");
      const invalidCount = (result.match(/<invalid>/g) || []).length;

      assert.strictEqual(
        invalidCount,
        0,
        "should not add <invalid> when key exists"
      );
    });
  });
});
