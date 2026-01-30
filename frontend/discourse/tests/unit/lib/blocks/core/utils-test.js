import { module, test } from "qunit";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";

module("Unit | Lib | blocks/core/utils", function () {
  module("applyArgDefaults", function () {
    test("returns original args when no schema", function (assert) {
      const ComponentClass = {
        blockMetadata: {},
      };
      const providedArgs = { title: "Hello", count: 5 };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, providedArgs);
    });

    test("returns original args when no blockMetadata", function (assert) {
      const ComponentClass = {};
      const providedArgs = { title: "Hello" };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, providedArgs);
    });

    test("applies defaults for undefined args", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            title: { type: "string", default: "Default Title" },
            count: { type: "number", default: 0 },
            enabled: { type: "boolean", default: true },
          },
        },
      };
      const providedArgs = {};

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, {
        title: "Default Title",
        count: 0,
        enabled: true,
      });
    });

    test("does not override provided args", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            title: { type: "string", default: "Default Title" },
            count: { type: "number", default: 0 },
          },
        },
      };
      const providedArgs = { title: "Custom Title", count: 42 };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, { title: "Custom Title", count: 42 });
    });

    test("applies defaults only for missing args (partial args)", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            title: { type: "string", default: "Default Title" },
            subtitle: { type: "string", default: "Default Subtitle" },
            count: { type: "number", default: 0 },
          },
        },
      };
      const providedArgs = { title: "Custom Title" };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, {
        title: "Custom Title",
        subtitle: "Default Subtitle",
        count: 0,
      });
    });

    test("does not apply defaults for args with no default value", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            title: { type: "string", required: true },
            count: { type: "number", default: 5 },
          },
        },
      };
      const providedArgs = {};

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.deepEqual(result, { count: 5 });
      assert.false("title" in result, "Title should not be added");
    });

    test("preserves null and false values in provided args", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            value: { type: "string", default: "default" },
            enabled: { type: "boolean", default: true },
          },
        },
      };
      const providedArgs = { value: null, enabled: false };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.strictEqual(result.value, null, "Null should be preserved");
      assert.false(result.enabled, "False should be preserved");
    });

    test("returns a new object (does not mutate input)", function (assert) {
      const ComponentClass = {
        blockMetadata: {
          args: {
            count: { type: "number", default: 0 },
          },
        },
      };
      const providedArgs = { title: "Hello" };

      const result = applyArgDefaults(ComponentClass, providedArgs);

      assert.notStrictEqual(result, providedArgs, "Should return new object");
      assert.deepEqual(
        providedArgs,
        { title: "Hello" },
        "Original should not be mutated"
      );
    });
  });
});
