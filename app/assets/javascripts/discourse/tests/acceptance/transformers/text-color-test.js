import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("category-text-color transformer", function () {
  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer("category-text-color", () => "FF0000");
    });

    await visit("/");

    const element = document.querySelector(
      "[data-topic-id='11994'] .badge-category__wrapper"
    );

    assert.strictEqual(
      window
        .getComputedStyle(element)
        .getPropertyValue("--category-badge-text-color"),
      "#FF0000",
      "it transforms the category text color"
    );
  });
});
