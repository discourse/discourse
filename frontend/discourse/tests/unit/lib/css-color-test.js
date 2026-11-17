import { module, test } from "qunit";
import { getCSSColor, getCSSColors } from "discourse/lib/css-color";

const TEST_VAR = "--css-color-test";
const OTHER_VAR = "--css-color-test-other";

module("Unit | Lib | cssColor", function (hooks) {
  let originalColorScheme;

  hooks.beforeEach(function () {
    document.documentElement.style.setProperty(
      TEST_VAR,
      "light-dark(#1f1f1f, #f8f5ee)"
    );
    originalColorScheme = document.documentElement.style.colorScheme;
  });

  hooks.afterEach(function () {
    document.documentElement.style.removeProperty(TEST_VAR);
    document.documentElement.style.removeProperty(OTHER_VAR);
    document.documentElement.style.colorScheme = originalColorScheme;
  });

  test("resolves light-dark() to a concrete color for the active scheme", function (assert) {
    document.documentElement.style.colorScheme = "light";
    assert.strictEqual(
      getCSSColor(TEST_VAR),
      "rgb(31, 31, 31)",
      "light scheme resolves to the light-dark() light value"
    );

    document.documentElement.style.colorScheme = "dark";
    assert.strictEqual(
      getCSSColor(TEST_VAR),
      "rgb(248, 245, 238)",
      "dark scheme resolves to the light-dark() dark value"
    );
  });

  test("returns a concrete color for a plain var() value", function (assert) {
    document.documentElement.style.setProperty(TEST_VAR, "#336699");
    assert.strictEqual(
      getCSSColor(TEST_VAR),
      "rgb(51, 102, 153)",
      "plain hex values pass through resolved"
    );
  });

  test("returns an empty string for an unset property", function (assert) {
    assert.strictEqual(
      getCSSColor("--css-color-test-unset"),
      "",
      "doesn't fall back to the inherited text color"
    );
  });

  test("resolves several properties at once", function (assert) {
    document.documentElement.style.colorScheme = "light";
    document.documentElement.style.setProperty(OTHER_VAR, "#336699");

    assert.deepEqual(
      getCSSColors([TEST_VAR, OTHER_VAR, "--css-color-test-unset"]),
      {
        [TEST_VAR]: "rgb(31, 31, 31)",
        [OTHER_VAR]: "rgb(51, 102, 153)",
        "--css-color-test-unset": "",
      },
      "each name maps to its resolved color"
    );
  });

  test("resolves properties scoped to a context element", function (assert) {
    const context = document.createElement("div");
    context.style.setProperty(OTHER_VAR, "#336699");
    document.body.append(context);

    try {
      assert.strictEqual(
        getCSSColor(OTHER_VAR, { context }),
        "rgb(51, 102, 153)",
        "reads the property from the context element"
      );
      assert.strictEqual(
        getCSSColor(OTHER_VAR),
        "",
        "the property isn't visible outside the context"
      );
    } finally {
      context.remove();
    }
  });
});
