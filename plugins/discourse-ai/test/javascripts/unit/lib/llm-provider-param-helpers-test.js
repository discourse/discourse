import { module, test } from "qunit";
import {
  isParamActive,
  isProviderParamHidden,
  normalizeProviderParams,
} from "discourse/plugins/discourse-ai/discourse/lib/llm-provider-param-helpers";

module("Discourse AI | Unit | Lib | llm-provider-param-helpers", function () {
  module("isParamActive", function () {
    test("returns false for null, undefined, and false", function (assert) {
      assert.false(isParamActive(null));
      assert.false(isParamActive(undefined));
      assert.false(isParamActive(false));
    });

    test("returns false for string 'false' and 'default'", function (assert) {
      assert.false(isParamActive("false"));
      assert.false(isParamActive("default"));
    });

    test("returns true for true and truthy strings", function (assert) {
      assert.true(isParamActive(true));
      assert.true(isParamActive("true"));
      assert.true(isParamActive("high"));
      assert.true(isParamActive("low"));
      assert.true(isParamActive("always"));
    });

    test("returns true for numbers", function (assert) {
      assert.true(isParamActive(1));
      assert.true(isParamActive(16000));
      assert.true(isParamActive(0));
    });

    test("returns false for empty string", function (assert) {
      assert.false(isParamActive(""));
    });
  });

  module("isProviderParamHidden", function () {
    test("returns false when no depends_on or hidden_if", function (assert) {
      assert.false(
        isProviderParamHidden({ type: "checkbox" }, { some_field: true })
      );
    });

    module("depends_on", function () {
      test("hidden when single dependency is inactive", function (assert) {
        assert.true(
          isProviderParamHidden(
            { type: "number", depends_on: "enable_reasoning" },
            { enable_reasoning: false }
          )
        );
      });

      test("visible when single dependency is active", function (assert) {
        assert.false(
          isProviderParamHidden(
            { type: "number", depends_on: "enable_reasoning" },
            { enable_reasoning: true }
          )
        );
      });

      test("hidden when any dependency in array is inactive", function (assert) {
        assert.true(
          isProviderParamHidden(
            { type: "checkbox", depends_on: ["parent_a", "parent_b"] },
            { parent_a: true, parent_b: null }
          )
        );
      });

      test("visible when all dependencies in array are active", function (assert) {
        assert.false(
          isProviderParamHidden(
            { type: "checkbox", depends_on: ["parent_a", "parent_b"] },
            { parent_a: true, parent_b: "high" }
          )
        );
      });

      test("hidden when dependency is 'default'", function (assert) {
        assert.true(
          isProviderParamHidden(
            { type: "number", depends_on: "thinking_level" },
            { thinking_level: "default" }
          )
        );
      });

      test("hidden when dependency key is missing from data", function (assert) {
        assert.true(
          isProviderParamHidden(
            { type: "number", depends_on: "enable_reasoning" },
            {}
          )
        );
      });
    });

    module("hidden_if", function () {
      test("hidden when single condition is active", function (assert) {
        assert.true(
          isProviderParamHidden(
            { type: "number", hidden_if: "adaptive_thinking" },
            { adaptive_thinking: true }
          )
        );
      });

      test("visible when single condition is inactive", function (assert) {
        assert.false(
          isProviderParamHidden(
            { type: "number", hidden_if: "adaptive_thinking" },
            { adaptive_thinking: false }
          )
        );
      });

      test("hidden when any condition in array is active", function (assert) {
        assert.true(
          isProviderParamHidden(
            {
              type: "checkbox",
              hidden_if: ["enable_reasoning", "adaptive_thinking"],
            },
            { enable_reasoning: false, adaptive_thinking: true }
          )
        );
      });

      test("visible when all conditions in array are inactive", function (assert) {
        assert.false(
          isProviderParamHidden(
            {
              type: "checkbox",
              hidden_if: ["enable_reasoning", "adaptive_thinking"],
            },
            { enable_reasoning: false, adaptive_thinking: "default" }
          )
        );
      });
    });

    module("depends_on + hidden_if combined", function () {
      test("hidden when dependency is inactive (depends_on takes priority)", function (assert) {
        assert.true(
          isProviderParamHidden(
            {
              type: "number",
              depends_on: "enable_reasoning",
              hidden_if: "adaptive_thinking",
            },
            { enable_reasoning: false, adaptive_thinking: false }
          )
        );
      });

      test("hidden when hidden_if condition is active", function (assert) {
        assert.true(
          isProviderParamHidden(
            {
              type: "number",
              depends_on: "enable_reasoning",
              hidden_if: "adaptive_thinking",
            },
            { enable_reasoning: true, adaptive_thinking: true }
          )
        );
      });

      test("visible when dependency active and hidden_if inactive", function (assert) {
        assert.false(
          isProviderParamHidden(
            {
              type: "number",
              depends_on: "enable_reasoning",
              hidden_if: "adaptive_thinking",
            },
            { enable_reasoning: true, adaptive_thinking: false }
          )
        );
      });
    });
  });

  module("normalizeProviderParams", function () {
    test("returns empty object for null/undefined input", function (assert) {
      assert.deepEqual(normalizeProviderParams(null), {});
      assert.deepEqual(normalizeProviderParams(undefined), {});
    });

    test("normalizes string shorthand to {type} object", function (assert) {
      const result = normalizeProviderParams({
        disable_native_tools: "checkbox",
        disable_system_prompt: "checkbox",
      });

      assert.deepEqual(result.disable_native_tools, { type: "checkbox" });
      assert.deepEqual(result.disable_system_prompt, { type: "checkbox" });
    });

    test("normalizes enum with values into id/name pairs", function (assert) {
      const result = normalizeProviderParams({
        effort: {
          type: "enum",
          values: ["default", "low", "medium", "high", "max"],
          default: "default",
        },
      });

      assert.strictEqual(result.effort.type, "enum");
      assert.strictEqual(result.effort.default, "default");
      assert.deepEqual(result.effort.values, [
        { id: "default", name: "default" },
        { id: "low", name: "low" },
        { id: "medium", name: "medium" },
        { id: "high", name: "high" },
        { id: "max", name: "max" },
      ]);
    });

    test("preserves depends_on and hidden_if metadata", function (assert) {
      const result = normalizeProviderParams({
        reasoning_tokens: {
          type: "number",
          depends_on: "enable_reasoning",
          hidden_if: "adaptive_thinking",
        },
      });

      assert.strictEqual(
        result.reasoning_tokens.depends_on,
        "enable_reasoning"
      );
      assert.strictEqual(
        result.reasoning_tokens.hidden_if,
        "adaptive_thinking"
      );
    });

    test("preserves array form of hidden_if", function (assert) {
      const result = normalizeProviderParams({
        disable_temperature: {
          type: "checkbox",
          hidden_if: ["enable_reasoning", "adaptive_thinking"],
        },
      });

      assert.deepEqual(result.disable_temperature.hidden_if, [
        "enable_reasoning",
        "adaptive_thinking",
      ]);
    });

    test("defaults type to 'text' for objects without type", function (assert) {
      const result = normalizeProviderParams({
        some_field: { depends_on: "parent" },
      });

      assert.strictEqual(result.some_field.type, "text");
    });

    test("defaults values to empty array for non-enum", function (assert) {
      const result = normalizeProviderParams({
        some_field: { type: "number" },
      });

      assert.deepEqual(result.some_field.values, []);
    });

    test("handles mixed param types in a single provider", function (assert) {
      const result = normalizeProviderParams({
        enable_reasoning: "checkbox",
        adaptive_thinking: {
          type: "checkbox",
          depends_on: "enable_reasoning",
        },
        reasoning_tokens: {
          type: "number",
          depends_on: "enable_reasoning",
          hidden_if: "adaptive_thinking",
        },
        effort: {
          type: "enum",
          values: ["default", "low", "high"],
          default: "default",
        },
      });

      assert.strictEqual(result.enable_reasoning.type, "checkbox");
      assert.strictEqual(result.adaptive_thinking.type, "checkbox");
      assert.strictEqual(
        result.adaptive_thinking.depends_on,
        "enable_reasoning"
      );
      assert.strictEqual(result.reasoning_tokens.type, "number");
      assert.strictEqual(result.effort.type, "enum");
      assert.strictEqual(result.effort.values.length, 3);
    });
  });
});
