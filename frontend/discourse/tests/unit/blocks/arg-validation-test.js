import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  VALID_CHILD_ARG_SCHEMA_PROPERTIES,
  validateChildArgsSchema,
} from "discourse/lib/blocks/validation/block-args";

module("Unit | Blocks | arg-validation", function (hooks) {
  setupTest(hooks);

  module("validateChildArgsSchema", function () {
    test("accepts valid childArgs schema with basic types", function (assert) {
      const schema = {
        name: { type: "string", required: true },
        count: { type: "number" },
        active: { type: "boolean" },
      };

      // Should not throw
      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "valid schema accepted");
    });

    test("accepts childArgs schema with unique property", function (assert) {
      const schema = {
        name: { type: "string", required: true, unique: true },
        id: { type: "number", unique: true },
      };

      // Should not throw
      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "schema with unique property accepted");
    });

    test("throws for invalid unique value type", function (assert) {
      const schema = {
        name: { type: "string", unique: "yes" },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /invalid "unique" value\. Must be a boolean/,
        "rejects non-boolean unique value"
      );
    });

    test("throws for unique: true with array type", function (assert) {
      const schema = {
        items: { type: "array", unique: true },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /has "unique: true" but type is "array"/,
        "rejects unique on array type"
      );
    });

    test("allows unique: true with string type", function (assert) {
      const schema = {
        name: { type: "string", unique: true },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "unique with string type accepted");
    });

    test("allows unique: true with number type", function (assert) {
      const schema = {
        id: { type: "number", unique: true },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "unique with number type accepted");
    });

    test("allows unique: true with boolean type", function (assert) {
      const schema = {
        flag: { type: "boolean", unique: true },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "unique with boolean type accepted");
    });

    test("throws for missing type property", function (assert) {
      const schema = {
        name: { required: true },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /missing required "type" property/,
        "rejects schema without type"
      );
    });

    test("throws for invalid type value", function (assert) {
      const schema = {
        name: { type: "invalid" },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /has invalid type/,
        "rejects invalid type"
      );
    });

    test("throws for invalid arg name format", function (assert) {
      const schema = {
        "123invalid": { type: "string" },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /arg name "123invalid" is invalid/,
        "rejects invalid arg name"
      );
    });

    test("throws for unknown properties", function (assert) {
      const schema = {
        name: { type: "string", unknownProp: true },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /has unknown properties/,
        "rejects unknown properties"
      );
    });

    test("throws for required + default combination", function (assert) {
      const schema = {
        name: { type: "string", required: true, default: "test" },
      };

      assert.throws(
        () => validateChildArgsSchema(schema, "test-container"),
        /has both "required: true" and "default"/,
        "rejects required + default"
      );
    });

    test("accepts schema with default value", function (assert) {
      const schema = {
        name: { type: "string", default: "default-name" },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "schema with default accepted");
    });

    test("accepts schema with pattern constraint", function (assert) {
      const schema = {
        name: { type: "string", pattern: /^[a-z]+$/ },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "schema with pattern accepted");
    });

    test("accepts schema with min/max constraints", function (assert) {
      const schema = {
        count: { type: "number", min: 0, max: 100 },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "schema with min/max accepted");
    });

    test("accepts schema with enum constraint", function (assert) {
      const schema = {
        color: { type: "string", enum: ["red", "green", "blue"] },
      };

      validateChildArgsSchema(schema, "test-container");
      assert.true(true, "schema with enum accepted");
    });

    test("accepts null or undefined schema", function (assert) {
      validateChildArgsSchema(null, "test-container");
      validateChildArgsSchema(undefined, "test-container");
      assert.true(true, "null/undefined schema accepted");
    });

    test("VALID_CHILD_ARG_SCHEMA_PROPERTIES includes unique", function (assert) {
      assert.true(
        VALID_CHILD_ARG_SCHEMA_PROPERTIES.includes("unique"),
        "unique is a valid child arg property"
      );
      assert.true(
        VALID_CHILD_ARG_SCHEMA_PROPERTIES.includes("type"),
        "type is a valid child arg property"
      );
      assert.true(
        VALID_CHILD_ARG_SCHEMA_PROPERTIES.includes("required"),
        "required is a valid child arg property"
      );
    });
  });
});
