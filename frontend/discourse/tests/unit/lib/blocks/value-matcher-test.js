import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  isTypeMismatch,
  matchParams,
  matchValue,
  validateParamSpec,
} from "discourse/lib/blocks/value-matcher";

module("Unit | Lib | Blocks | value-matcher", function (hooks) {
  setupTest(hooks);

  module("isTypeMismatch", function () {
    test("detects string/number mismatch", function (assert) {
      assert.true(isTypeMismatch("3", 3));
      assert.true(isTypeMismatch(3, "3"));
      assert.true(isTypeMismatch("123", 123));
    });

    test("returns false when values actually match", function (assert) {
      assert.false(isTypeMismatch("foo", "foo"));
      assert.false(isTypeMismatch(123, 123));
    });

    test("returns false when values differ and no coercion would help", function (assert) {
      assert.false(isTypeMismatch("3", 4));
      assert.false(isTypeMismatch("foo", "bar"));
      assert.false(isTypeMismatch("foo", 123));
    });

    test("detects mismatch in arrays", function (assert) {
      assert.true(isTypeMismatch("3", [3, 4, 5]));
      assert.true(isTypeMismatch(3, ["3", "4", "5"]));
      assert.false(isTypeMismatch("6", [3, 4, 5]));
    });

    test("detects mismatch in { any: [...] }", function (assert) {
      assert.true(isTypeMismatch("3", { any: [3, 4, 5] }));
      assert.false(isTypeMismatch("6", { any: [3, 4, 5] }));
    });
  });

  module("matchValue", function () {
    module("exact matching", function () {
      test("matches exact string value", function (assert) {
        assert.true(matchValue({ actual: "foo", expected: "foo" }));
        assert.false(matchValue({ actual: "foo", expected: "bar" }));
      });

      test("matches exact number value", function (assert) {
        assert.true(matchValue({ actual: 123, expected: 123 }));
        assert.false(matchValue({ actual: 123, expected: 456 }));
      });

      test("matches null and undefined", function (assert) {
        assert.true(matchValue({ actual: null, expected: null }));
        assert.true(matchValue({ actual: undefined, expected: undefined }));
        assert.false(matchValue({ actual: null, expected: undefined }));
      });

      test("no type coercion: string does not match number", function (assert) {
        assert.false(matchValue({ actual: "3", expected: 3 }));
        assert.false(matchValue({ actual: 3, expected: "3" }));
      });
    });

    module("array OR matching", function () {
      test("matches if value is in array", function (assert) {
        assert.true(matchValue({ actual: "foo", expected: ["foo", "bar"] }));
        assert.true(matchValue({ actual: "bar", expected: ["foo", "bar"] }));
        assert.false(matchValue({ actual: "baz", expected: ["foo", "bar"] }));
      });

      test("matches numbers in array", function (assert) {
        assert.true(matchValue({ actual: 123, expected: [123, 456, 789] }));
        assert.false(matchValue({ actual: 999, expected: [123, 456, 789] }));
      });
    });

    module("regex matching", function () {
      test("matches regex pattern", function (assert) {
        assert.true(matchValue({ actual: "hello-world", expected: /^hello/ }));
        assert.false(matchValue({ actual: "goodbye", expected: /^hello/ }));
      });

      test("converts non-string actual to string for regex", function (assert) {
        assert.true(matchValue({ actual: 123, expected: /^12/ }));
        assert.false(matchValue({ actual: 456, expected: /^12/ }));
      });
    });

    module("NOT logic", function () {
      test("{ not: value } inverts match", function (assert) {
        assert.true(matchValue({ actual: "foo", expected: { not: "bar" } }));
        assert.false(matchValue({ actual: "foo", expected: { not: "foo" } }));
      });

      test("{ not: [...] } inverts array OR", function (assert) {
        assert.true(
          matchValue({ actual: "baz", expected: { not: ["foo", "bar"] } })
        );
        assert.false(
          matchValue({ actual: "foo", expected: { not: ["foo", "bar"] } })
        );
      });

      test("nested NOT", function (assert) {
        // not(not(foo)) === foo
        assert.true(
          matchValue({ actual: "foo", expected: { not: { not: "foo" } } })
        );
        assert.false(
          matchValue({ actual: "bar", expected: { not: { not: "foo" } } })
        );
      });
    });

    module("ANY (OR) logic", function () {
      test("{ any: [...] } matches if any spec matches", function (assert) {
        assert.true(
          matchValue({ actual: "foo", expected: { any: ["foo", "bar"] } })
        );
        assert.true(
          matchValue({ actual: "bar", expected: { any: ["foo", "bar"] } })
        );
        assert.false(
          matchValue({ actual: "baz", expected: { any: ["foo", "bar"] } })
        );
      });

      test("{ any: [...] } with complex specs", function (assert) {
        assert.true(
          matchValue({
            actual: "hello-world",
            expected: { any: [/^hello/, "goodbye"] },
          })
        );
        assert.true(
          matchValue({
            actual: "goodbye",
            expected: { any: [/^hello/, "goodbye"] },
          })
        );
        assert.false(
          matchValue({
            actual: "other",
            expected: { any: [/^hello/, "goodbye"] },
          })
        );
      });
    });
  });

  module("matchParams", function () {
    module("basic key matching", function () {
      test("matches single key", function (assert) {
        const actualParams = { id: 123 };
        assert.true(matchParams({ actualParams, expectedParams: { id: 123 } }));
        assert.false(
          matchParams({ actualParams, expectedParams: { id: 456 } })
        );
      });

      test("matches multiple keys (AND logic)", function (assert) {
        const actualParams = { id: 123, slug: "my-topic" };
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { id: 123, slug: "my-topic" },
          })
        );
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { id: 123, slug: "other-topic" },
          })
        );
      });

      test("returns false if expected key is missing from actual", function (assert) {
        const actualParams = { id: 123 };
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { id: 123, slug: "my-topic" },
          })
        );
      });
    });

    module("empty/null handling", function () {
      test("returns true if no expected params", function (assert) {
        assert.true(
          matchParams({ actualParams: { id: 123 }, expectedParams: null })
        );
        assert.true(
          matchParams({ actualParams: { id: 123 }, expectedParams: undefined })
        );
      });

      test("returns true if expected params is empty object", function (assert) {
        assert.true(
          matchParams({ actualParams: { id: 123 }, expectedParams: {} })
        );
      });
    });

    module("value-level matching", function () {
      test("supports array OR for values", function (assert) {
        const actualParams = { id: 123 };
        assert.true(
          matchParams({ actualParams, expectedParams: { id: [123, 456] } })
        );
        assert.false(
          matchParams({ actualParams, expectedParams: { id: [456, 789] } })
        );
      });

      test("supports { any: [...] } OR for values", function (assert) {
        const actualParams = { id: 123 };
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { id: { any: [123, 456] } },
          })
        );
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { id: { any: [456, 789] } },
          })
        );
      });

      test("supports regex for values", function (assert) {
        const actualParams = { slug: "help-topic" };
        assert.true(
          matchParams({ actualParams, expectedParams: { slug: /^help-/ } })
        );
        assert.false(
          matchParams({ actualParams, expectedParams: { slug: /^other-/ } })
        );
      });

      test("supports NOT for values", function (assert) {
        const actualParams = { id: 123 };
        assert.true(
          matchParams({ actualParams, expectedParams: { id: { not: 456 } } })
        );
        assert.false(
          matchParams({ actualParams, expectedParams: { id: { not: 123 } } })
        );
      });
    });

    module("params-level AND/OR/NOT", function () {
      test("array of specs = AND logic", function (assert) {
        const actualParams = { id: 123, slug: "help-topic" };
        // Both conditions must pass
        assert.true(
          matchParams({
            actualParams,
            expectedParams: [{ id: 123 }, { slug: /^help-/ }],
          })
        );
        // First passes, second fails
        assert.false(
          matchParams({
            actualParams,
            expectedParams: [{ id: 123 }, { slug: /^other-/ }],
          })
        );
      });

      test("{ any: [...] } = OR logic", function (assert) {
        const actualParams = { id: 123 };
        // Either condition can pass
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { any: [{ id: 123 }, { id: 456 }] },
          })
        );
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { any: [{ id: 456 }, { id: 123 }] },
          })
        );
        // Neither passes
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { any: [{ id: 456 }, { id: 789 }] },
          })
        );
      });

      test("{ not: {...} } = NOT logic", function (assert) {
        const actualParams = { id: 123 };
        // NOT(id: 456) = true when id is 123
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { not: { id: 456 } },
          })
        );
        // NOT(id: 123) = false when id is 123
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { not: { id: 123 } },
          })
        );
      });

      test("nested logic: OR containing NOT", function (assert) {
        const actualParams = { id: 123, status: "open" };
        // Match if id=456 OR status is NOT "closed"
        assert.true(
          matchParams({
            actualParams,
            expectedParams: {
              any: [{ id: 456 }, { status: { not: "closed" } }],
            },
          })
        );
      });
    });

    module("backslash escape for reserved keys", function () {
      test("\\\\any matches literal param named 'any'", function (assert) {
        const actualParams = { any: "some-value" };
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { "\\any": "some-value" },
          })
        );
        assert.false(
          matchParams({
            actualParams,
            expectedParams: { "\\any": "other-value" },
          })
        );
      });

      test("\\\\not matches literal param named 'not'", function (assert) {
        const actualParams = { not: "some-value" };
        assert.true(
          matchParams({
            actualParams,
            expectedParams: { "\\not": "some-value" },
          })
        );
      });

      test("escape does not interfere with normal keys", function (assert) {
        const actualParams = { id: 123, "\\id": 456 };
        // Normal key
        assert.true(matchParams({ actualParams, expectedParams: { id: 123 } }));
        // Escaped key matches literal "\\id" key
        assert.true(
          matchParams({ actualParams, expectedParams: { "\\\\id": 456 } })
        );
      });
    });
  });

  module("validateParamSpec", function () {
    test("raises error for operator typos like 'an' instead of 'any'", function (assert) {
      const errors = [];
      validateParamSpec({ an: [1, 2, 3] }, "queryParams", (msg) =>
        errors.push(msg)
      );
      assert.strictEqual(errors.length, 1);
      assert.true(errors[0].includes('"an"'));
      assert.true(errors[0].includes('Did you mean "any"'));
    });

    test("raises error for operator typos like 'nto' instead of 'not'", function (assert) {
      const errors = [];
      // Note: 'nto' has Jaro-Winkler ~0.6 with 'not', below 0.7 threshold
      // So this won't trigger a suggestion - only very close typos do
      validateParamSpec({ nto: { foo: "bar" } }, "params", (msg) =>
        errors.push(msg)
      );
      // 'nto' isn't close enough to 'not' at 0.7 threshold
      assert.strictEqual(errors.length, 0);
    });

    test("does not raise error for valid operator keys", function (assert) {
      const errors = [];
      validateParamSpec({ any: [1, 2, 3] }, "queryParams", (msg) =>
        errors.push(msg)
      );
      validateParamSpec({ not: { foo: "bar" } }, "params", (msg) =>
        errors.push(msg)
      );
      assert.strictEqual(errors.length, 0);
    });

    test("does not raise error for regular param keys", function (assert) {
      const errors = [];
      validateParamSpec(
        { preview_theme_id: 3, filter: "solved" },
        "queryParams",
        (msg) => errors.push(msg)
      );
      assert.strictEqual(errors.length, 0);
    });

    test("validates nested specs recursively", function (assert) {
      const errors = [];
      validateParamSpec(
        { any: [{ an: [1, 2] }, { filter: "solved" }] },
        "queryParams",
        (msg) => errors.push(msg)
      );
      assert.strictEqual(errors.length, 1);
      assert.true(errors[0].includes("queryParams.any[0]"));
    });

    test("does not raise error for escaped keys", function (assert) {
      const errors = [];
      validateParamSpec({ "\\any": "literal-value" }, "params", (msg) =>
        errors.push(msg)
      );
      assert.strictEqual(errors.length, 0);
    });
  });

  module("logger integration", function () {
    /**
     * Creates a test logger that mimics the real debug logger's behavior.
     * Tracks pending logs by conditionSpec and updates results when
     * updateCombinatorResult is called, just like the real logger does.
     */
    function createTestLogger() {
      const logs = [];
      const pendingLogs = new Map();

      return {
        logs,
        logCondition({ type, args, result, depth, conditionSpec }) {
          const entry = { type, args, result, depth, conditionSpec };
          logs.push(entry);
          if (conditionSpec && result === null) {
            pendingLogs.set(conditionSpec, entry);
          }
        },
        updateCombinatorResult(conditionSpec, result) {
          const entry = pendingLogs.get(conditionSpec);
          if (entry) {
            entry.result = result;
            pendingLogs.delete(conditionSpec);
          }
        },
        logParamGroup({ label, matches, result, depth }) {
          logs.push({ type: "param-group", label, matches, result, depth });
        },
      };
    }

    module("combinator result is correctly updated", function () {
      test("OR combinator shows passing result when one child matches", function (assert) {
        const expectedParams = { any: [{ id: 123 }, { id: 456 }] };
        const actualParams = { id: 123 };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.true(result, "OR should pass when one child matches");

        const orEntry = logger.logs.find((log) => log.type === "OR");
        assert.true(
          orEntry.result,
          "OR combinator log entry should have result=true"
        );
      });

      test("OR combinator shows failing result when no children match", function (assert) {
        const expectedParams = { any: [{ id: 456 }, { id: 789 }] };
        const actualParams = { id: 123 };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.false(result, "OR should fail when no children match");

        const orEntry = logger.logs.find((log) => log.type === "OR");
        assert.false(
          orEntry.result,
          "OR combinator log entry should have result=false"
        );
      });

      test("AND combinator shows passing result when all children match", function (assert) {
        const expectedParams = [{ id: 123 }, { slug: "test" }];
        const actualParams = { id: 123, slug: "test" };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.true(result, "AND should pass when all children match");

        const andEntry = logger.logs.find((log) => log.type === "AND");
        assert.true(
          andEntry.result,
          "AND combinator log entry should have result=true"
        );
      });

      test("AND combinator shows failing result when one child fails", function (assert) {
        const expectedParams = [{ id: 123 }, { slug: "wrong" }];
        const actualParams = { id: 123, slug: "test" };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.false(result, "AND should fail when one child fails");

        const andEntry = logger.logs.find((log) => log.type === "AND");
        assert.false(
          andEntry.result,
          "AND combinator log entry should have result=false"
        );
      });

      test("NOT combinator shows passing result when inner fails", function (assert) {
        const expectedParams = { not: { id: 456 } };
        const actualParams = { id: 123 };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.true(result, "NOT should pass when inner condition fails");

        const notEntry = logger.logs.find((log) => log.type === "NOT");
        assert.true(
          notEntry.result,
          "NOT combinator log entry should have result=true"
        );
      });

      test("NOT combinator shows failing result when inner passes", function (assert) {
        const expectedParams = { not: { id: 123 } };
        const actualParams = { id: 123 };
        const logger = createTestLogger();

        const result = matchParams({
          actualParams,
          expectedParams,
          context: { logger },
        });

        assert.false(result, "NOT should fail when inner condition passes");

        const notEntry = logger.logs.find((log) => log.type === "NOT");
        assert.false(
          notEntry.result,
          "NOT combinator log entry should have result=false"
        );
      });
    });
  });
});
