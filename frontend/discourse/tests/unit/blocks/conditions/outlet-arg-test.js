import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockOutletArgCondition from "discourse/blocks/conditions/outlet-arg";
import { validateConditions } from "discourse/tests/helpers/block-testing";

module("Unit | Blocks | Condition | outlet-arg", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockOutletArgCondition();
    setOwner(this.condition, getOwner(this));

    // Helper to validate via infrastructure
    this.validateCondition = (args) => {
      const conditionTypes = new Map([["outlet-arg", this.condition]]);

      try {
        validateConditions({ type: "outlet-arg", ...args }, conditionTypes);
        return null;
      } catch (error) {
        return error;
      }
    };
  });

  module("validate (through infrastructure)", function () {
    test("returns error when path is missing", function (assert) {
      const error = this.validateCondition({});
      assert.true(error?.message.includes("missing required arg"));
    });

    test("returns error when path is not a string (schema type validation)", function (assert) {
      const error = this.validateCondition({ path: 123 });
      assert.true(error?.message.includes("must be a string"));
    });

    test("returns error when path contains invalid characters (custom validation)", function (assert) {
      const error = this.validateCondition({ path: "user-name", value: true });
      assert.true(error?.message.includes("is invalid"));
    });

    test("returns error when both value and exists are specified (exactlyOne constraint)", function (assert) {
      const error = this.validateCondition({
        path: "user",
        value: true,
        exists: true,
      });
      assert.true(error?.message.includes("exactly one of"));
    });

    test("returns error when neither value nor exists is specified (exactlyOne constraint)", function (assert) {
      const error = this.validateCondition({
        path: "user",
      });
      assert.true(error?.message.includes("exactly one of"));
    });

    test("accepts valid path with value", function (assert) {
      assert.strictEqual(
        this.validateCondition({ path: "user.admin", value: true }),
        null
      );
    });

    test("accepts valid path with exists", function (assert) {
      assert.strictEqual(
        this.validateCondition({ path: "topic", exists: true }),
        null
      );
    });

    test("accepts dot-notation paths", function (assert) {
      assert.strictEqual(
        this.validateCondition({ path: "user.trust_level", value: 2 }),
        null
      );
    });

    test("returns error when exists is not a boolean (schema type validation)", function (assert) {
      const error = this.validateCondition({ path: "user", exists: "true" });
      assert.true(error?.message.includes("must be a boolean"));
    });
  });

  module("evaluate", function () {
    test("returns true when property matches value", function (assert) {
      const context = { outletArgs: { user: { admin: true } } };
      const result = this.condition.evaluate(
        { path: "user.admin", value: true },
        context
      );
      assert.true(result);
    });

    test("returns false when property does not match value", function (assert) {
      const context = { outletArgs: { user: { admin: false } } };
      const result = this.condition.evaluate(
        { path: "user.admin", value: true },
        context
      );
      assert.false(result);
    });

    test("returns true when value matches exactly", function (assert) {
      const context = { outletArgs: { topic: { closed: true } } };
      const result = this.condition.evaluate(
        { path: "topic.closed", value: true },
        context
      );
      assert.true(result);
    });

    test("returns false when value does not match exactly", function (assert) {
      const context = { outletArgs: { topic: { closed: false } } };
      const result = this.condition.evaluate(
        { path: "topic.closed", value: true },
        context
      );
      assert.false(result);
    });

    test("supports array value matching (OR logic)", function (assert) {
      const context = { outletArgs: { user: { trust_level: 2 } } };
      const result = this.condition.evaluate(
        { path: "user.trust_level", value: [2, 3, 4] },
        context
      );
      assert.true(result);
    });

    test("returns false when value not in array", function (assert) {
      const context = { outletArgs: { user: { trust_level: 1 } } };
      const result = this.condition.evaluate(
        { path: "user.trust_level", value: [2, 3, 4] },
        context
      );
      assert.false(result);
    });

    test("supports negation with { not: value }", function (assert) {
      const context = { outletArgs: { topic: { closed: false } } };
      const result = this.condition.evaluate(
        { path: "topic.closed", value: { not: true } },
        context
      );
      assert.true(result);
    });

    test("exists: true passes when property exists", function (assert) {
      const context = { outletArgs: { topic: { title: "Hello" } } };
      const result = this.condition.evaluate(
        { path: "topic.title", exists: true },
        context
      );
      assert.true(result);
    });

    test("exists: true fails when property is undefined", function (assert) {
      const context = { outletArgs: { topic: {} } };
      const result = this.condition.evaluate(
        { path: "topic.title", exists: true },
        context
      );
      assert.false(result);
    });

    test("exists: false passes when property is undefined", function (assert) {
      const context = { outletArgs: { topic: {} } };
      const result = this.condition.evaluate(
        { path: "topic.title", exists: false },
        context
      );
      assert.true(result);
    });

    test("exists: false fails when property exists", function (assert) {
      const context = { outletArgs: { topic: { title: "Hello" } } };
      const result = this.condition.evaluate(
        { path: "topic.title", exists: false },
        context
      );
      assert.false(result);
    });

    test("handles missing outletArgs gracefully", function (assert) {
      const result = this.condition.evaluate(
        { path: "user.admin", value: true },
        {}
      );
      assert.false(result);
    });

    test("handles null outletArgs gracefully", function (assert) {
      const result = this.condition.evaluate(
        { path: "user.admin", value: true },
        { outletArgs: null }
      );
      assert.false(result);
    });

    test("handles deeply nested paths", function (assert) {
      const context = {
        outletArgs: { topic: { category: { parent: { id: 5 } } } },
      };
      const result = this.condition.evaluate(
        { path: "topic.category.parent.id", value: 5 },
        context
      );
      assert.true(result);
    });

    test("returns false for non-existent path", function (assert) {
      const context = { outletArgs: { topic: {} } };
      const result = this.condition.evaluate(
        { path: "topic.category.id", value: 5 },
        context
      );
      assert.false(result);
    });

    module("nested path error handling", function () {
      test("handles null intermediate value in nested path", function (assert) {
        const context = { outletArgs: { topic: { category: null } } };
        const result = this.condition.evaluate(
          { path: "topic.category.id", value: 5 },
          context
        );
        assert.false(result);
      });

      test("handles undefined intermediate value in nested path", function (assert) {
        const context = { outletArgs: { topic: { category: undefined } } };
        const result = this.condition.evaluate(
          { path: "topic.category.parent.id", value: 5 },
          context
        );
        assert.false(result);
      });

      test("handles missing root property in nested path", function (assert) {
        const context = { outletArgs: {} };
        const result = this.condition.evaluate(
          { path: "topic.category.parent.id", value: 5 },
          context
        );
        assert.false(result);
      });

      test("handles deeply nested path with null at various levels", function (assert) {
        // null at first level
        let context = { outletArgs: { a: null } };
        assert.false(
          this.condition.evaluate({ path: "a.b.c.d", value: 1 }, context),
          "null at first level"
        );

        // null at second level
        context = { outletArgs: { a: { b: null } } };
        assert.false(
          this.condition.evaluate({ path: "a.b.c.d", value: 1 }, context),
          "null at second level"
        );

        // null at third level
        context = { outletArgs: { a: { b: { c: null } } } };
        assert.false(
          this.condition.evaluate({ path: "a.b.c.d", value: 1 }, context),
          "null at third level"
        );
      });

      test("handles exists: true with null intermediate value", function (assert) {
        const context = { outletArgs: { topic: { category: null } } };
        const result = this.condition.evaluate(
          { path: "topic.category.id", exists: true },
          context
        );
        assert.false(result);
      });

      test("handles exists: false with null intermediate value", function (assert) {
        const context = { outletArgs: { topic: { category: null } } };
        const result = this.condition.evaluate(
          { path: "topic.category.id", exists: false },
          context
        );
        assert.true(result);
      });

      test("handles value check with missing nested path", function (assert) {
        const context = { outletArgs: { topic: null } };
        const result = this.condition.evaluate(
          { path: "topic.closed", value: true },
          context
        );
        assert.false(result);
      });
    });
  });
});
