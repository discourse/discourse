import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("composer-force-editor-mode transformer", function (needs) {
  needs.user();
  needs.settings({
    rich_editor: true,
    allow_uncategorized_topics: true,
  });

  test("forces markdown mode and hides toggle", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "composer-force-editor-mode",
        ({ context }) => {
          if (context.model?.action === "createTopic") {
            return "markdown";
          }
          return null;
        }
      );
    });

    await visit("/new-topic");

    assert
      .dom(".composer-toggle-switch")
      .doesNotExist("toggle is hidden when forceEditorMode is set");

    assert
      .dom("textarea.d-editor-input")
      .exists("uses textarea editor instead of rich editor");
  });

  test("allows rich editor when transformer returns null", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "composer-force-editor-mode",
        () => null // Don't force any mode
      );
    });

    await visit("/new-topic");

    assert
      .dom(".composer-toggle-switch")
      .exists("toggle is visible when forceEditorMode is not set");
  });
});
