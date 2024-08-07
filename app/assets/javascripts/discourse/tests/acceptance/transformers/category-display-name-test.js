import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("category-display-name transformer", function () {
  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "category-display-name",
        ({ value, context }) =>
          value + "-" + context.category.id + "-transformed"
      );
    });

    await visit("/");

    assert
      .dom("[data-topic-id='11997'] .badge-category__name")
      .hasText(
        "feature-2-transformed",
        "it transforms the category display name"
      );
  });
});
