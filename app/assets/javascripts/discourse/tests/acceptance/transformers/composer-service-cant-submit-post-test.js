import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("composer-service-cannot-submit-post transformer", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
  });

  test("applying a value transformation - disable submit", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "composer-service-cannot-submit-post",
        () => {
          // Return true -- explicitly block submission!
          return true;
        }
      );
    });

    await visit("/new-topic?title=topic title that is pretty long");
    await fillIn(".d-editor-input", "this is the *content* of a post");
    await click(".submit-panel .create");

    assert.dom(".d-editor-input").exists("composer is still open");
  });

  test("applying a value transformation - allow submission", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "composer-service-cannot-submit-post",
        ({ value }) => {
          // Return value (which should be `false`, as we have a valid new topic to create)
          return value;
        }
      );
    });

    await visit("/new-topic?title=topic title that is pretty long");
    await fillIn(".d-editor-input", "this is the *content* of a post");
    await click(".submit-panel .create");

    assert
      .dom(".d-editor-input")
      .doesNotExist("closes the composer on successful creation");
  });
});
