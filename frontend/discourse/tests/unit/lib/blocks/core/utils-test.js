import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { applyArgDefaults } from "discourse/lib/blocks/-internals/utils";

module("Unit | Lib | blocks/core/utils", function () {
  module("applyArgDefaults", function () {
    test("returns original args when no schema", function (assert) {
      @block("no-schema-block")
      class NoSchemaBlock extends Component {}

      const providedArgs = { title: "Hello", count: 5 };
      const result = applyArgDefaults(NoSchemaBlock, providedArgs);

      assert.deepEqual(result, providedArgs);
    });

    test("returns original args when component is not a block", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}
      const providedArgs = { title: "Hello" };

      const result = applyArgDefaults(PlainComponent, providedArgs);

      assert.deepEqual(result, providedArgs);
    });

    test("applies defaults for undefined args", function (assert) {
      @block("defaults-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          count: { type: "number", default: 0 },
          enabled: { type: "boolean", default: true },
        },
      })
      class DefaultsBlock extends Component {}

      const providedArgs = {};
      const result = applyArgDefaults(DefaultsBlock, providedArgs);

      assert.deepEqual(result, {
        title: "Default Title",
        count: 0,
        enabled: true,
      });
    });

    test("does not override provided args", function (assert) {
      @block("override-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          count: { type: "number", default: 0 },
        },
      })
      class OverrideBlock extends Component {}

      const providedArgs = { title: "Custom Title", count: 42 };
      const result = applyArgDefaults(OverrideBlock, providedArgs);

      assert.deepEqual(result, { title: "Custom Title", count: 42 });
    });

    test("applies defaults only for missing args (partial args)", function (assert) {
      @block("partial-args-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          subtitle: { type: "string", default: "Default Subtitle" },
          count: { type: "number", default: 0 },
        },
      })
      class PartialArgsBlock extends Component {}

      const providedArgs = { title: "Custom Title" };
      const result = applyArgDefaults(PartialArgsBlock, providedArgs);

      assert.deepEqual(result, {
        title: "Custom Title",
        subtitle: "Default Subtitle",
        count: 0,
      });
    });

    test("does not apply defaults for args with no default value", function (assert) {
      @block("no-default-block", {
        args: {
          title: { type: "string", required: true },
          count: { type: "number", default: 5 },
        },
      })
      class NoDefaultBlock extends Component {}

      const providedArgs = {};
      const result = applyArgDefaults(NoDefaultBlock, providedArgs);

      assert.deepEqual(result, { count: 5 });
      assert.false("title" in result, "Title should not be added");
    });

    test("preserves null and false values in provided args", function (assert) {
      @block("preserve-values-block", {
        args: {
          value: { type: "string", default: "default" },
          enabled: { type: "boolean", default: true },
        },
      })
      class PreserveValuesBlock extends Component {}

      const providedArgs = { value: null, enabled: false };
      const result = applyArgDefaults(PreserveValuesBlock, providedArgs);

      assert.strictEqual(result.value, null, "Null should be preserved");
      assert.false(result.enabled, "False should be preserved");
    });

    test("returns a new object (does not mutate input)", function (assert) {
      @block("immutable-block", {
        args: {
          count: { type: "number", default: 0 },
        },
      })
      class ImmutableBlock extends Component {}

      const providedArgs = { title: "Hello" };
      const result = applyArgDefaults(ImmutableBlock, providedArgs);

      assert.notStrictEqual(result, providedArgs, "Should return new object");
      assert.deepEqual(
        providedArgs,
        { title: "Hello" },
        "Original should not be mutated"
      );
    });
  });
});
