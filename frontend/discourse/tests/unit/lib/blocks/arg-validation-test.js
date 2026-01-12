import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import {
  validateArgsSchema,
  validateArgValue,
  validateArrayItemType,
  validateBlockArgs,
} from "discourse/lib/blocks/arg-validation";
import {
  runCustomValidation,
  validateConstraints,
  validateConstraintsSchema,
} from "discourse/lib/blocks/constraint-validation";
import { BlockError } from "discourse/lib/blocks/error";

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

    test("throws for required with default - contradictory options", function (assert) {
      const schema = {
        title: { type: "string", required: true, default: "Hello" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has both "required: true" and "default".*contradictory/
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

    test("throws for min on non-number type", function (assert) {
      const schema = {
        title: { type: "string", min: 0 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "min" but type is "string".*only valid for number type/
      );
    });

    test("throws for max on non-number type", function (assert) {
      const schema = {
        title: { type: "string", max: 100 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "max" but type is "string".*only valid for number type/
      );
    });

    test("throws for integer on non-number type", function (assert) {
      const schema = {
        title: { type: "string", integer: true },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "integer" but type is "string".*only valid for number type/
      );
    });

    test("throws for non-number min value", function (assert) {
      const schema = {
        count: { type: "number", min: "0" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "min" value.*Must be a number/
      );
    });

    test("throws for non-number max value", function (assert) {
      const schema = {
        count: { type: "number", max: "100" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "max" value.*Must be a number/
      );
    });

    test("throws for non-boolean integer value", function (assert) {
      const schema = {
        count: { type: "number", integer: "true" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "integer" value.*Must be a boolean/
      );
    });

    test("throws for min greater than max", function (assert) {
      const schema = {
        count: { type: "number", min: 100, max: 0 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has min \(100\) greater than max \(0\)/
      );
    });

    test("accepts valid min/max/integer on number type", function (assert) {
      const schema = {
        count: { type: "number", min: 0, max: 100 },
        page: { type: "number", min: 1, integer: true },
        percentage: { type: "number", min: 0, max: 1 },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("throws for default value below min", function (assert) {
      const schema = {
        count: { type: "number", min: 0, default: -5 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be at least 0/
      );
    });

    test("throws for default value above max", function (assert) {
      const schema = {
        count: { type: "number", max: 100, default: 150 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be at most 100/
      );
    });

    test("throws for non-integer default with integer constraint", function (assert) {
      const schema = {
        count: { type: "number", integer: true, default: 5.5 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be an integer/
      );
    });

    test("throws for minLength on non-string/array type", function (assert) {
      const schema = {
        count: { type: "number", minLength: 1 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "minLength" but type is "number".*only valid for string or array type/
      );
    });

    test("throws for maxLength on non-string/array type", function (assert) {
      const schema = {
        enabled: { type: "boolean", maxLength: 10 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "maxLength" but type is "boolean".*only valid for string or array type/
      );
    });

    test("throws for non-integer minLength value", function (assert) {
      const schema = {
        title: { type: "string", minLength: 1.5 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "minLength" value.*Must be a non-negative integer/
      );
    });

    test("throws for negative minLength value", function (assert) {
      const schema = {
        title: { type: "string", minLength: -1 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "minLength" value.*Must be a non-negative integer/
      );
    });

    test("throws for non-integer maxLength value", function (assert) {
      const schema = {
        title: { type: "string", maxLength: "10" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "maxLength" value.*Must be a non-negative integer/
      );
    });

    test("throws for minLength greater than maxLength", function (assert) {
      const schema = {
        title: { type: "string", minLength: 10, maxLength: 5 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has minLength \(10\) greater than maxLength \(5\)/
      );
    });

    test("accepts valid minLength/maxLength on string type", function (assert) {
      const schema = {
        title: { type: "string", minLength: 1, maxLength: 100 },
        name: { type: "string", minLength: 0 },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("accepts valid minLength/maxLength on array type", function (assert) {
      const schema = {
        tags: { type: "array", minLength: 1, maxLength: 10 },
        items: { type: "array", minLength: 0 },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("throws for enum on non-string/number type", function (assert) {
      const schema = {
        enabled: { type: "boolean", enum: [true, false] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /has "enum" but type is "boolean".*only valid for string or number type/
      );
    });

    test("throws for enum that is not an array", function (assert) {
      const schema = {
        size: { type: "string", enum: "small" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "enum" value.*Must be an array with at least one element/
      );
    });

    test("throws for empty enum array", function (assert) {
      const schema = {
        size: { type: "string", enum: [] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid "enum" value.*Must be an array with at least one element/
      );
    });

    test("throws for enum with wrong value types - string", function (assert) {
      const schema = {
        size: { type: "string", enum: ["small", 123] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /enum contains invalid value.*All values must be strings/
      );
    });

    test("throws for enum with wrong value types - number", function (assert) {
      const schema = {
        priority: { type: "number", enum: [1, 2, "high"] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /enum contains invalid value.*All values must be numbers/
      );
    });

    test("accepts valid string enum", function (assert) {
      const schema = {
        size: { type: "string", enum: ["small", "medium", "large"] },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("accepts valid number enum", function (assert) {
      const schema = {
        priority: { type: "number", enum: [1, 2, 3, 5, 8] },
      };

      assert.strictEqual(
        validateArgsSchema(schema, "test-block"),
        undefined,
        "no error thrown"
      );
    });

    test("throws for default value not in enum - string", function (assert) {
      const schema = {
        size: {
          type: "string",
          enum: ["small", "medium", "large"],
          default: "huge",
        },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be one of/
      );
    });

    test("throws for default value not in enum - number", function (assert) {
      const schema = {
        priority: { type: "number", enum: [1, 2, 3], default: 5 },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be one of/
      );
    });

    test("throws for default string below minLength", function (assert) {
      const schema = {
        title: { type: "string", minLength: 5, default: "Hi" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be at least 5 characters/
      );
    });

    test("throws for default string above maxLength", function (assert) {
      const schema = {
        code: { type: "string", maxLength: 3, default: "TOOLONG" },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must be at most 3 characters/
      );
    });

    test("throws for default array below minLength", function (assert) {
      const schema = {
        tags: { type: "array", minLength: 2, default: ["one"] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must have at least 2 items/
      );
    });

    test("throws for default array above maxLength", function (assert) {
      const schema = {
        tags: { type: "array", maxLength: 2, default: ["a", "b", "c"] },
      };

      assert.throws(
        () => validateArgsSchema(schema, "test-block"),
        /invalid default value.*must have at most 2 items/
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

    test("validates string with minLength constraint", function (assert) {
      const schema = { type: "string", minLength: 3 };

      assert.strictEqual(
        validateArgValue("abc", schema, "title", "test-block"),
        null,
        "exact minLength passes"
      );

      assert.strictEqual(
        validateArgValue("abcdef", schema, "title", "test-block"),
        null,
        "above minLength passes"
      );

      assert.true(
        validateArgValue("ab", schema, "title", "test-block")?.includes(
          "must be at least 3 characters"
        ),
        "below minLength fails"
      );
    });

    test("validates string with maxLength constraint", function (assert) {
      const schema = { type: "string", maxLength: 5 };

      assert.strictEqual(
        validateArgValue("abcde", schema, "title", "test-block"),
        null,
        "exact maxLength passes"
      );

      assert.strictEqual(
        validateArgValue("abc", schema, "title", "test-block"),
        null,
        "below maxLength passes"
      );

      assert.true(
        validateArgValue("abcdef", schema, "title", "test-block")?.includes(
          "must be at most 5 characters"
        ),
        "above maxLength fails"
      );
    });

    test("validates string with enum constraint", function (assert) {
      const schema = { type: "string", enum: ["small", "medium", "large"] };

      assert.strictEqual(
        validateArgValue("small", schema, "size", "test-block"),
        null,
        "valid enum value passes"
      );

      assert.strictEqual(
        validateArgValue("large", schema, "size", "test-block"),
        null,
        "another valid enum value passes"
      );

      assert.true(
        validateArgValue("huge", schema, "size", "test-block")?.includes(
          'must be one of: "small", "medium", "large"'
        ),
        "invalid enum value fails"
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

    test("validates number with min constraint", function (assert) {
      const schema = { type: "number", min: 0 };

      assert.strictEqual(
        validateArgValue(0, schema, "count", "test-block"),
        null,
        "min boundary passes"
      );

      assert.strictEqual(
        validateArgValue(100, schema, "count", "test-block"),
        null,
        "above min passes"
      );

      assert.true(
        validateArgValue(-1, schema, "count", "test-block")?.includes(
          "must be at least 0"
        ),
        "below min fails"
      );
    });

    test("validates number with max constraint", function (assert) {
      const schema = { type: "number", max: 100 };

      assert.strictEqual(
        validateArgValue(100, schema, "count", "test-block"),
        null,
        "max boundary passes"
      );

      assert.strictEqual(
        validateArgValue(0, schema, "count", "test-block"),
        null,
        "below max passes"
      );

      assert.true(
        validateArgValue(101, schema, "count", "test-block")?.includes(
          "must be at most 100"
        ),
        "above max fails"
      );
    });

    test("validates number with integer constraint", function (assert) {
      const schema = { type: "number", integer: true };

      assert.strictEqual(
        validateArgValue(42, schema, "count", "test-block"),
        null,
        "integer passes"
      );

      assert.strictEqual(
        validateArgValue(0, schema, "count", "test-block"),
        null,
        "zero passes"
      );

      assert.strictEqual(
        validateArgValue(-5, schema, "count", "test-block"),
        null,
        "negative integer passes"
      );

      assert.true(
        validateArgValue(3.14, schema, "count", "test-block")?.includes(
          "must be an integer"
        ),
        "float fails"
      );
    });

    test("validates number with combined constraints", function (assert) {
      const schema = { type: "number", min: 1, max: 10, integer: true };

      assert.strictEqual(
        validateArgValue(5, schema, "page", "test-block"),
        null,
        "valid value passes"
      );

      assert.true(
        validateArgValue(0, schema, "page", "test-block")?.includes(
          "must be at least 1"
        ),
        "below min fails"
      );

      assert.true(
        validateArgValue(11, schema, "page", "test-block")?.includes(
          "must be at most 10"
        ),
        "above max fails"
      );

      assert.true(
        validateArgValue(5.5, schema, "page", "test-block")?.includes(
          "must be an integer"
        ),
        "non-integer fails"
      );
    });

    test("validates number with enum constraint", function (assert) {
      const schema = { type: "number", enum: [1, 2, 3, 5, 8] };

      assert.strictEqual(
        validateArgValue(1, schema, "priority", "test-block"),
        null,
        "valid enum value passes"
      );

      assert.strictEqual(
        validateArgValue(8, schema, "priority", "test-block"),
        null,
        "another valid enum value passes"
      );

      assert.true(
        validateArgValue(4, schema, "priority", "test-block")?.includes(
          "must be one of: 1, 2, 3, 5, 8"
        ),
        "invalid enum value fails"
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

    test("validates array with minLength constraint", function (assert) {
      const schema = { type: "array", minLength: 2 };

      assert.strictEqual(
        validateArgValue(["a", "b"], schema, "tags", "test-block"),
        null,
        "exact minLength passes"
      );

      assert.strictEqual(
        validateArgValue(["a", "b", "c"], schema, "tags", "test-block"),
        null,
        "above minLength passes"
      );

      assert.true(
        validateArgValue(["a"], schema, "tags", "test-block")?.includes(
          "must have at least 2 items"
        ),
        "below minLength fails"
      );
    });

    test("validates array with maxLength constraint", function (assert) {
      const schema = { type: "array", maxLength: 3 };

      assert.strictEqual(
        validateArgValue(["a", "b", "c"], schema, "tags", "test-block"),
        null,
        "exact maxLength passes"
      );

      assert.strictEqual(
        validateArgValue(["a"], schema, "tags", "test-block"),
        null,
        "below maxLength passes"
      );

      assert.true(
        validateArgValue(
          ["a", "b", "c", "d"],
          schema,
          "tags",
          "test-block"
        )?.includes("must have at most 3 items"),
        "above maxLength fails"
      );
    });

    test("validates array with combined constraints", function (assert) {
      const schema = {
        type: "array",
        minLength: 1,
        maxLength: 5,
        itemType: "string",
      };

      assert.strictEqual(
        validateArgValue(["a", "b", "c"], schema, "tags", "test-block"),
        null,
        "valid array passes"
      );

      assert.true(
        validateArgValue([], schema, "tags", "test-block")?.includes(
          "must have at least 1 items"
        ),
        "empty array fails"
      );

      assert.true(
        validateArgValue(
          ["a", "b", "c", "d", "e", "f"],
          schema,
          "tags",
          "test-block"
        )?.includes("must have at most 5 items"),
        "too many items fails"
      );

      assert.true(
        validateArgValue(
          ["a", 123, "c"],
          schema,
          "tags",
          "test-block"
        )?.includes("must be a string"),
        "wrong item type fails"
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
        assert.true(error instanceof BlockError);
        assert.true(error.message.includes("missing required args.title"));
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
        assert.true(error instanceof BlockError);
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
        assert.true(error instanceof BlockError);
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
        assert.true(error instanceof BlockError);
        assert.true(error.message.includes('unknown args "unknownArg"'));
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
        assert.true(error instanceof BlockError);
        assert.true(error.message.includes("shoDescription"));
        assert.true(error.message.includes('did you mean "showDescription"'));
        assert.strictEqual(error.path, "args.shoDescription");
      }
    });
  });

  module("validateConstraintsSchema", function () {
    test("accepts valid constraints", function (assert) {
      const constraints = {
        atLeastOne: ["id", "tag"],
      };
      const argsSchema = {
        id: { type: "number" },
        tag: { type: "string" },
      };

      assert.strictEqual(
        validateConstraintsSchema(constraints, argsSchema, "test-block"),
        undefined
      );
    });

    test("accepts null/undefined constraints", function (assert) {
      assert.strictEqual(
        validateConstraintsSchema(null, {}, "test-block"),
        undefined
      );
      assert.strictEqual(
        validateConstraintsSchema(undefined, {}, "test-block"),
        undefined
      );
    });

    test("throws for unknown constraint type", function (assert) {
      const constraints = {
        invalidConstraint: ["id", "tag"],
      };
      const argsSchema = {
        id: { type: "number" },
        tag: { type: "string" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /unknown constraint type "invalidConstraint"/
      );
    });

    test("suggests similar constraint type for typos", function (assert) {
      const constraints = {
        atleastOne: ["id", "tag"],
      };
      const argsSchema = {
        id: { type: "number" },
        tag: { type: "string" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /did you mean "atLeastOne"/
      );
    });

    test("throws if constraint value is not an array", function (assert) {
      const constraints = {
        atLeastOne: "id",
      };
      const argsSchema = {
        id: { type: "number" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /must be an array of arg names/
      );
    });

    test("throws if constraint has fewer than 2 args", function (assert) {
      const constraints = {
        atLeastOne: ["id"],
      };
      const argsSchema = {
        id: { type: "number" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /must reference at least 2 args/
      );
    });

    test("throws if constraint references unknown arg", function (assert) {
      const constraints = {
        atLeastOne: ["id", "unknownArg"],
      };
      const argsSchema = {
        id: { type: "number" },
        tag: { type: "string" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /references unknown arg "unknownArg"/
      );
    });

    test("suggests similar arg name for typos in constraint", function (assert) {
      const constraints = {
        atLeastOne: ["id", "tagh"],
      };
      const argsSchema = {
        id: { type: "number" },
        tag: { type: "string" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /did you mean "tag"/
      );
    });

    test("throws if constraint contains non-string value", function (assert) {
      const constraints = {
        atLeastOne: ["id", 123],
      };
      const argsSchema = {
        id: { type: "number" },
      };

      assert.throws(
        () => validateConstraintsSchema(constraints, argsSchema, "test-block"),
        /contains non-string value/
      );
    });

    module("vacuous constraint detection", function () {
      test("atLeastOne is vacuous when arg has default", function (assert) {
        const constraints = {
          atLeastOne: ["id", "tag"],
        };
        const argsSchema = {
          id: { type: "number", default: 1 },
          tag: { type: "string" },
        };

        assert.throws(
          () =>
            validateConstraintsSchema(constraints, argsSchema, "test-block"),
          /atLeastOne.*is always true because "id" has a default value/
        );
      });

      test("exactlyOne is vacuous when multiple args have defaults", function (assert) {
        const constraints = {
          exactlyOne: ["id", "tag"],
        };
        const argsSchema = {
          id: { type: "number", default: 1 },
          tag: { type: "string", default: "foo" },
        };

        assert.throws(
          () =>
            validateConstraintsSchema(constraints, argsSchema, "test-block"),
          /exactlyOne.*is always false because multiple args have default values/
        );
      });

      test("exactlyOne is valid when only one arg has default", function (assert) {
        const constraints = {
          exactlyOne: ["id", "tag"],
        };
        const argsSchema = {
          id: { type: "number", default: 1 },
          tag: { type: "string" },
        };

        assert.strictEqual(
          validateConstraintsSchema(constraints, argsSchema, "test-block"),
          undefined
        );
      });

      test("allOrNone is vacuous when some but not all have defaults", function (assert) {
        const constraints = {
          allOrNone: ["width", "height"],
        };
        const argsSchema = {
          width: { type: "number", default: 100 },
          height: { type: "number" },
        };

        assert.throws(
          () =>
            validateConstraintsSchema(constraints, argsSchema, "test-block"),
          /allOrNone.*is always false because only some args have defaults/
        );
      });

      test("allOrNone is valid when all have defaults", function (assert) {
        const constraints = {
          allOrNone: ["width", "height"],
        };
        const argsSchema = {
          width: { type: "number", default: 100 },
          height: { type: "number", default: 200 },
        };

        assert.strictEqual(
          validateConstraintsSchema(constraints, argsSchema, "test-block"),
          undefined
        );
      });

      test("allOrNone is valid when none have defaults", function (assert) {
        const constraints = {
          allOrNone: ["width", "height"],
        };
        const argsSchema = {
          width: { type: "number" },
          height: { type: "number" },
        };

        assert.strictEqual(
          validateConstraintsSchema(constraints, argsSchema, "test-block"),
          undefined
        );
      });
    });

    module("incompatible constraint detection", function () {
      test("exactlyOne + allOrNone on same args is an error", function (assert) {
        const constraints = {
          exactlyOne: ["id", "tag"],
          allOrNone: ["id", "tag"],
        };
        const argsSchema = {
          id: { type: "number" },
          tag: { type: "string" },
        };

        assert.throws(
          () =>
            validateConstraintsSchema(constraints, argsSchema, "test-block"),
          /"exactlyOne" and "allOrNone" conflict/
        );
      });

      test("exactlyOne + atLeastOne on same args is an error", function (assert) {
        const constraints = {
          exactlyOne: ["id", "tag"],
          atLeastOne: ["id", "tag"],
        };
        const argsSchema = {
          id: { type: "number" },
          tag: { type: "string" },
        };

        assert.throws(
          () =>
            validateConstraintsSchema(constraints, argsSchema, "test-block"),
          /"atLeastOne" is redundant with "exactlyOne"/
        );
      });

      test("different constraints on different args is valid", function (assert) {
        const constraints = {
          exactlyOne: ["id", "tag"],
          allOrNone: ["width", "height"],
        };
        const argsSchema = {
          id: { type: "number" },
          tag: { type: "string" },
          width: { type: "number" },
          height: { type: "number" },
        };

        assert.strictEqual(
          validateConstraintsSchema(constraints, argsSchema, "test-block"),
          undefined
        );
      });
    });
  });

  module("validateConstraints", function () {
    module("atLeastOne", function () {
      test("passes when one arg is provided", function (assert) {
        const constraints = { atLeastOne: ["id", "tag"] };
        const args = { id: 123 };

        assert.strictEqual(
          validateConstraints(constraints, args, "test-block"),
          null
        );
      });

      test("passes when multiple args are provided", function (assert) {
        const constraints = { atLeastOne: ["id", "tag"] };
        const args = { id: 123, tag: "foo" };

        assert.strictEqual(
          validateConstraints(constraints, args, "test-block"),
          null
        );
      });

      test("fails when no args are provided", function (assert) {
        const constraints = { atLeastOne: ["id", "tag"] };
        const args = {};

        const error = validateConstraints(constraints, args, "test-block");
        assert.true(error.includes('at least one of "id", "tag"'));
        assert.true(error.includes("must be provided"));
      });
    });

    module("exactlyOne", function () {
      test("passes when exactly one arg is provided", function (assert) {
        const constraints = { exactlyOne: ["id", "tag"] };
        const args = { id: 123 };

        assert.strictEqual(
          validateConstraints(constraints, args, "test-block"),
          null
        );
      });

      test("fails when no args are provided", function (assert) {
        const constraints = { exactlyOne: ["id", "tag"] };
        const args = {};

        const error = validateConstraints(constraints, args, "test-block");
        assert.true(error.includes('exactly one of "id", "tag"'));
        assert.true(error.includes("but got none"));
      });

      test("fails when multiple args are provided", function (assert) {
        const constraints = { exactlyOne: ["id", "tag"] };
        const args = { id: 123, tag: "foo" };

        const error = validateConstraints(constraints, args, "test-block");
        assert.true(error.includes('exactly one of "id", "tag"'));
        assert.true(error.includes("but got 2"));
      });
    });

    module("allOrNone", function () {
      test("passes when all args are provided", function (assert) {
        const constraints = { allOrNone: ["width", "height"] };
        const args = { width: 100, height: 200 };

        assert.strictEqual(
          validateConstraints(constraints, args, "test-block"),
          null
        );
      });

      test("passes when no args are provided", function (assert) {
        const constraints = { allOrNone: ["width", "height"] };
        const args = {};

        assert.strictEqual(
          validateConstraints(constraints, args, "test-block"),
          null
        );
      });

      test("fails when some but not all args are provided", function (assert) {
        const constraints = { allOrNone: ["width", "height"] };
        const args = { width: 100 };

        const error = validateConstraints(constraints, args, "test-block");
        assert.true(error.includes('"width", "height"'));
        assert.true(error.includes("must be provided together or not at all"));
        assert.true(error.includes('missing "height"'));
      });
    });

    test("accepts null/undefined constraints", function (assert) {
      assert.strictEqual(validateConstraints(null, {}, "test-block"), null);
      assert.strictEqual(
        validateConstraints(undefined, {}, "test-block"),
        null
      );
    });

    test("validates multiple constraints", function (assert) {
      const constraints = {
        atLeastOne: ["a", "b"],
        allOrNone: ["x", "y"],
      };
      const args = { a: 1, x: 10 };

      const error = validateConstraints(constraints, args, "test-block");
      assert.true(error.includes('missing "y"'));
    });
  });

  module("runCustomValidation", function () {
    test("returns null when validate returns undefined", function (assert) {
      const validateFn = () => undefined;

      assert.strictEqual(runCustomValidation(validateFn, {}), null);
    });

    test("returns null when validate returns null", function (assert) {
      const validateFn = () => null;

      assert.strictEqual(runCustomValidation(validateFn, {}), null);
    });

    test("returns array with single error when validate returns string", function (assert) {
      const validateFn = () => "min must be less than max";

      const errors = runCustomValidation(validateFn, {});
      assert.deepEqual(errors, ["min must be less than max"]);
    });

    test("returns array when validate returns array of strings", function (assert) {
      const validateFn = () => ["error 1", "error 2"];

      const errors = runCustomValidation(validateFn, {});
      assert.deepEqual(errors, ["error 1", "error 2"]);
    });

    test("filters out non-string and empty values from array", function (assert) {
      const validateFn = () => ["valid error", "", 123, null, "another error"];

      const errors = runCustomValidation(validateFn, {});
      assert.deepEqual(errors, ["valid error", "another error"]);
    });

    test("returns null for empty array", function (assert) {
      const validateFn = () => [];

      assert.strictEqual(runCustomValidation(validateFn, {}), null);
    });

    test("returns null for non-function validateFn", function (assert) {
      assert.strictEqual(runCustomValidation(null, {}), null);
      assert.strictEqual(runCustomValidation(undefined, {}), null);
      assert.strictEqual(runCustomValidation("not a function", {}), null);
    });

    test("passes args to validate function", function (assert) {
      let receivedArgs;
      const validateFn = (args) => {
        receivedArgs = args;
        return null;
      };

      const testArgs = { min: 5, max: 10 };
      runCustomValidation(validateFn, testArgs);

      assert.strictEqual(receivedArgs, testArgs);
    });

    test("can validate args relationships", function (assert) {
      const validateFn = (args) => {
        if (args.min > args.max) {
          return "min must be less than or equal to max";
        }
      };

      assert.strictEqual(
        runCustomValidation(validateFn, { min: 5, max: 10 }),
        null
      );
      assert.deepEqual(runCustomValidation(validateFn, { min: 15, max: 10 }), [
        "min must be less than or equal to max",
      ]);
    });
  });

  module("@block decorator with constraints", function () {
    test("stores constraints in block metadata", function (assert) {
      @block("constraint-metadata-block", {
        args: {
          id: { type: "number" },
          tag: { type: "string" },
        },
        constraints: {
          atLeastOne: ["id", "tag"],
        },
      })
      class ConstraintMetadataBlock extends Component {}

      assert.deepEqual(ConstraintMetadataBlock.blockMetadata.constraints, {
        atLeastOne: ["id", "tag"],
      });
    });

    test("stores validate function in block metadata", function (assert) {
      const validateFn = (args) => {
        if (args.min > args.max) {
          return "min must be less than max";
        }
      };

      @block("validate-fn-block", {
        args: {
          min: { type: "number" },
          max: { type: "number" },
        },
        validate: validateFn,
      })
      class ValidateFnBlock extends Component {}

      assert.strictEqual(
        ValidateFnBlock.blockMetadata.validate,
        validateFn,
        "validate function is stored"
      );
    });

    test("throws at decoration time for invalid constraints", function (assert) {
      assert.throws(() => {
        @block("invalid-constraint-block", {
          args: {
            id: { type: "number" },
          },
          constraints: {
            unknownConstraint: ["id", "other"],
          },
        })
        class InvalidConstraintBlock extends Component {}
        return InvalidConstraintBlock;
      }, /unknown constraint type/);
    });
  });
});
