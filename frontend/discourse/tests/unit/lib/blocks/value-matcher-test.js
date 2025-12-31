import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { matchParams, matchValue } from "discourse/lib/blocks/value-matcher";

module("Unit | Lib | Blocks | value-matcher", function (hooks) {
  setupTest(hooks);

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
});
