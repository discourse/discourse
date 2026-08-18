import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("composer-minimum-post-length transformer", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
    min_first_post_length: 20,
  });

  test("the default value comes from the site settings", async function (assert) {
    await visit("/new-topic?title=topic title that is pretty long");
    await click(".submit-panel .create");

    assert.dom(".d-editor-input").exists("the body is still required");
  });

  test("returning 0 lets an empty body through", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("composer-minimum-post-length", () => 0);
    });

    await visit("/new-topic?title=topic title that is pretty long");
    await click(".submit-panel .create");

    assert
      .dom(".d-editor-input")
      .doesNotExist("closes the composer on successful creation");
  });
});
