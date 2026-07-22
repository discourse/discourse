import { module, test } from "qunit";
import configureTestFilter from "discourse/tests/helpers/configure-test-filter";

module("Unit | Helper | configure-test-filter", function () {
  test("preserves native QUnit filtering without a mode marker", function (assert) {
    const config = { filter: "DButton" };

    configureTestFilter(config, new URLSearchParams("filter=DButton"));

    assert.strictEqual(
      config.filter,
      "DButton",
      "the native filter remains configured"
    );
    assert.strictEqual(
      config.testFilter,
      undefined,
      "a custom filter is not installed"
    );
  });

  test("treats a marked literal filter as literal text", function (assert) {
    const config = { filter: "Integration | ui-kit | DButton" };
    const queryParams = new URLSearchParams(
      "filter=Integration+%7C+ui-kit+%7C+DButton&discourseTestFilterMode=literal"
    );

    configureTestFilter(config, queryParams);

    assert.strictEqual(
      config.filter,
      undefined,
      "the native filter is disabled"
    );
    assert.true(
      config.testFilter({
        module: "Integration | ui-kit | DButton",
        testName: "aria-label",
      }),
      "the complete literal text matches"
    );
    assert.false(
      config.testFilter({ module: "Integration", testName: "DButton" }),
      "the pipe is not treated as alternation"
    );
  });

  test("treats a marked regex filter as a regular expression", function (assert) {
    const config = { filter: "DButton|DIconGridPicker" };
    const queryParams = new URLSearchParams(
      "filter=DButton%7CDIconGridPicker&discourseTestFilterMode=regex"
    );

    configureTestFilter(config, queryParams);

    assert.strictEqual(
      config.filter,
      undefined,
      "the native filter is disabled"
    );
    assert.true(
      config.testFilter({ module: "Integration", testName: "DButton" }),
      "the first alternative matches"
    );
    assert.true(
      config.testFilter({
        module: "Integration",
        testName: "DIconGridPicker",
      }),
      "the second alternative matches"
    );
  });

  test("throws a clear error for an invalid regex filter", function (assert) {
    const config = { filter: "(" };
    const queryParams = new URLSearchParams(
      "filter=%28&discourseTestFilterMode=regex"
    );

    assert.throws(
      () => configureTestFilter(config, queryParams),
      /Invalid --filter-regex pattern: \(/,
      "the malformed pattern is named in the error"
    );
  });
});
