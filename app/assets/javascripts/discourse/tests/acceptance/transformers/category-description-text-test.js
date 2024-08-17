import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("category-description-text transformer", function () {
  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "category-description-text",
        ({ value, context }) =>
          value[0] + "-" + context.category.id + "-transformed"
      );
    });

    await visit("/");

    assert
      .dom("[data-topic-id='11994'] .badge-category")
      .hasAttribute(
        "title",
        "A-1-transformed",
        "it transforms the category description text"
      );
  });
});
