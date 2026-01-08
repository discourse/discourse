import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import {
  validateArgsSchema,
  validateArgValue,
  validateArrayItemType,
  validateBlockArgs,
} from "discourse/lib/blocks/arg-validation";
import { BlockValidationError } from "discourse/lib/blocks/error";

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
        /unknown properties: "unknownProp"/
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

    test("throws for pattern on non-string type", function (assert) {
      const schema = {
        count: { type: "number", pattern: /^\d+$/ },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /"pattern" is only valid for string type/
      );
    });

    test("throws for non-RegExp pattern", function (assert) {
      const schema = {
        name: { type: "string", pattern: "^[a-z]+$" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "pattern" value. Must be a RegExp/
      );
    });

    test("accepts valid pattern on string type", function (assert) {
      const schema = {
        name: { type: "string", pattern: /^[a-z][a-z0-9-]*$/ },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("throws for default value not matching pattern", function (assert) {
      const schema = {
        name: {
          type: "string",
          pattern: /^[a-z][a-z0-9-]*$/,
          default: "Invalid_Name",
        },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*does not match required pattern/
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

    test("validates string with pattern - valid value", function (assert) {
      assert.strictEqual(
        validateArgValue(
          "valid-name",
          { type: "string", pattern: /^[a-z][a-z0-9-]*$/ },
          "name",
          "test-block"
        ),
        null
      );
    });

    test("validates string with pattern - invalid value", function (assert) {
      const result = validateArgValue(
        "Invalid_Name",
        { type: "string", pattern: /^[a-z][a-z0-9-]*$/ },
        "name",
        "test-block"
      );
      assert.true(result?.includes("does not match required pattern"));
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

      try {
        validateBlockArgs({ args: {} }, RequiredArgsBlock);
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(error instanceof BlockValidationError);
        assert.true(error.message.includes('missing required arg "title"'));
        assert.strictEqual(error.path, "args.title");
      }
    });

    test("validates arg types", function (assert) {
      @block("typed-args-block", {
        args: {
          count: { type: "number" },
        },
      })
      class TypedArgsBlock extends Component {}

      try {
        validateBlockArgs({ args: { count: "not-a-number" } }, TypedArgsBlock);
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(error instanceof BlockValidationError);
        assert.true(error.message.includes("must be a number"));
        assert.strictEqual(error.path, "args.count");
      }
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
          { args: { title: "Hello", count: 5 } },
          ValidArgsBlock
        ),
        undefined
      );
    });

    test("throws when args provided but no schema declared", function (assert) {
      @block("no-schema-block")
      class NoSchemaBlock extends Component {}

      try {
        validateBlockArgs({ args: { anything: "goes" } }, NoSchemaBlock);
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(error instanceof BlockValidationError);
        assert.true(error.message.includes("does not declare an args schema"));
        assert.strictEqual(error.path, "args");
      }
    });

    test("passes when no args and no schema", function (assert) {
      @block("no-args-no-schema-block")
      class NoArgsNoSchemaBlock extends Component {}

      assert.strictEqual(
        validateBlockArgs({ args: {} }, NoArgsNoSchemaBlock),
        undefined
      );
      assert.strictEqual(validateBlockArgs({}, NoArgsNoSchemaBlock), undefined);
    });

    test("throws for unknown args not declared in schema", function (assert) {
      @block("known-args-block", {
        args: {
          title: { type: "string" },
        },
      })
      class KnownArgsBlock extends Component {}

      try {
        validateBlockArgs(
          { args: { title: "valid", unknownArg: "bad" } },
          KnownArgsBlock
        );
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(error instanceof BlockValidationError);
        assert.true(error.message.includes('unknown arg "unknownArg"'));
        assert.strictEqual(error.path, "args.unknownArg");
      }
    });

    test("suggests correct arg name for typos", function (assert) {
      @block("typo-args-block", {
        args: {
          showDescription: { type: "boolean" },
        },
      })
      class TypoArgsBlock extends Component {}

      try {
        validateBlockArgs({ args: { shoDescription: true } }, TypoArgsBlock);
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(error instanceof BlockValidationError);
        assert.true(error.message.includes("shoDescription"));
        assert.true(error.message.includes('did you mean "showDescription"'));
        assert.strictEqual(error.path, "args.shoDescription");
      }
    });
  });
});
