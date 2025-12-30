import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import {
  validateArgsSchema,
  validateArgValue,
  validateArrayItemType,
  validateBlockArgs,
} from "discourse/lib/blocks/arg-validation";

module("Unit | Lib | blocks/arg-validation", function () {
  module("validateArgsSchema", function () {
    test("accepts valid schema with all types", function (assert) {
      const schema = {
        title: { type: "string", required: true },
        count: { type: "number", default: 5 },
        enabled: { type: "boolean" },
        tags: { type: "array", itemType: "string" },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("accepts null/undefined schema", function (assert) {
      assert.strictEqual(validateArgsSchema(null, "test-block"), undefined);
      assert.strictEqual(
        validateArgsSchema(undefined, "test-block"),
        undefined
      );
    });

    test("throws for missing type property", function (assert) {
      const schema = {
        title: { required: true },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /missing required "type" property/
      );
    });

    test("throws for invalid type", function (assert) {
      const schema = {
        title: { type: "invalid" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid type "invalid"/
      );
    });

    test("throws for unknown schema properties", function (assert) {
      const schema = {
        title: { type: "string", unknownProp: true },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /unknown properties: unknownProp/
      );
    });

    test("throws for itemType on non-array type", function (assert) {
      const schema = {
        title: { type: "string", itemType: "string" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /"itemType" is only valid for array type/
      );
    });

    test("throws for invalid itemType", function (assert) {
      const schema = {
        tags: { type: "array", itemType: "object" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid itemType "object"/
      );
    });

    test("throws for non-boolean required", function (assert) {
      const schema = {
        title: { type: "string", required: "yes" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "required" value/
      );
    });

    test("throws for default value with wrong type - string expected", function (assert) {
      const schema = {
        title: { type: "string", default: 123 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be a string/
      );
    });

    test("throws for default value with wrong type - number expected", function (assert) {
      const schema = {
        count: { type: "number", default: "five" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be a number/
      );
    });

    test("throws for default value with wrong type - boolean expected", function (assert) {
      const schema = {
        enabled: { type: "boolean", default: "true" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be a boolean/
      );
    });

    test("throws for default value with wrong type - array expected", function (assert) {
      const schema = {
        tags: { type: "array", default: "tag1,tag2" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be an array/
      );
    });

    test("throws for default array with wrong item types", function (assert) {
      const schema = {
        tags: { type: "array", itemType: "string", default: ["valid", 123] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be a string/
      );
    });

    test("accepts valid default values", function (assert) {
      const schema = {
        title: { type: "string", default: "Hello" },
        count: { type: "number", default: 42 },
        enabled: { type: "boolean", default: true },
        tags: { type: "array", itemType: "string", default: ["a", "b"] },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });
  });

  module("validateArgValue", function () {
    test("returns null for undefined value", function (assert) {
      const result = validateArgValue(
        undefined,
        { type: "string" },
        "title",
        "test-block"
      );
      assert.strictEqual(result, null);
    });

    test("validates string type", function (assert) {
      assert.strictEqual(
        validateArgValue("hello", { type: "string" }, "title", "test-block"),
        null
      );

      assert.true(
        validateArgValue(
          123,
          { type: "string" },
          "title",
          "test-block"
        )?.includes("must be a string")
      );
    });

    test("validates number type", function (assert) {
      assert.strictEqual(
        validateArgValue(42, { type: "number" }, "count", "test-block"),
        null
      );

      assert.true(
        validateArgValue(
          "42",
          { type: "number" },
          "count",
          "test-block"
        )?.includes("must be a number")
      );

      assert.true(
        validateArgValue(
          NaN,
          { type: "number" },
          "count",
          "test-block"
        )?.includes("must be a number")
      );
    });

    test("validates boolean type", function (assert) {
      assert.strictEqual(
        validateArgValue(true, { type: "boolean" }, "enabled", "test-block"),
        null
      );

      assert.true(
        validateArgValue(
          "true",
          { type: "boolean" },
          "enabled",
          "test-block"
        )?.includes("must be a boolean")
      );
    });

    test("validates array type", function (assert) {
      assert.strictEqual(
        validateArgValue(["a", "b"], { type: "array" }, "tags", "test-block"),
        null
      );

      assert.true(
        validateArgValue(
          "not-an-array",
          { type: "array" },
          "tags",
          "test-block"
        )?.includes("must be an array")
      );
    });

    test("validates array itemType", function (assert) {
      assert.strictEqual(
        validateArgValue(
          ["a", "b", "c"],
          { type: "array", itemType: "string" },
          "tags",
          "test-block"
        ),
        null
      );

      assert.true(
        validateArgValue(
          ["a", 123, "c"],
          { type: "array", itemType: "string" },
          "tags",
          "test-block"
        )?.includes("must be a string")
      );
    });
  });

  module("validateArrayItemType", function () {
    test("validates string items", function (assert) {
      assert.strictEqual(
        validateArrayItemType("hello", "string", "tags", "test-block", 0),
        null
      );

      assert.true(
        validateArrayItemType(123, "string", "tags", "test-block", 0)?.includes(
          'tags[0]" must be a string'
        )
      );
    });

    test("validates number items", function (assert) {
      assert.strictEqual(
        validateArrayItemType(42, "number", "ids", "test-block", 0),
        null
      );

      assert.true(
        validateArrayItemType("42", "number", "ids", "test-block", 1)?.includes(
          'ids[1]" must be a number'
        )
      );
    });

    test("validates boolean items", function (assert) {
      assert.strictEqual(
        validateArrayItemType(true, "boolean", "flags", "test-block", 0),
        null
      );

      assert.true(
        validateArrayItemType(1, "boolean", "flags", "test-block", 2)?.includes(
          'flags[2]" must be a boolean'
        )
      );
    });
  });

  module("validateBlockArgs", function () {
    test("validates required args are present", function (assert) {
      @block("required-args-block", {
        args: {
          title: { type: "string", required: true },
        },
      })
      class RequiredArgsBlock extends Component {}

      assert.throws(
        () =>
          validateBlockArgs(
            { block: RequiredArgsBlock, args: {} },
            "test-outlet"
          ),
        /missing required arg "title"/
      );
    });

    test("validates arg types", function (assert) {
      @block("typed-args-block", {
        args: {
          count: { type: "number" },
        },
      })
      class TypedArgsBlock extends Component {}

      assert.throws(
        () =>
          validateBlockArgs(
            { block: TypedArgsBlock, args: { count: "not-a-number" } },
            "test-outlet"
          ),
        /must be a number/
      );
    });

    test("passes for valid args", function (assert) {
      @block("valid-args-block", {
        args: {
          title: { type: "string", required: true },
          count: { type: "number" },
        },
      })
      class ValidArgsBlock extends Component {}

      assert.strictEqual(
        validateBlockArgs(
          { block: ValidArgsBlock, args: { title: "Hello", count: 5 } },
          "test-outlet"
        ),
        undefined
      );
    });

    test("skips validation for blocks without metadata", function (assert) {
      @block("no-metadata-block")
      class NoMetadataBlock extends Component {}

      assert.strictEqual(
        validateBlockArgs(
          { block: NoMetadataBlock, args: { anything: "goes" } },
          "test-outlet"
        ),
        undefined
      );
    });
  });
});
