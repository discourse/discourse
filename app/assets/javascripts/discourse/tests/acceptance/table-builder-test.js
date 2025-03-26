import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Table Builder (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });
      needs.user();

      test("Can see table builder button when creating a topic", async function (assert) {
        await visit("/");
        await click("#create-topic");
        await click(".d-editor-button-bar .options");
        await selectKit(".toolbar-popup-menu-options").expand();

        assert
          .dom(`.select-kit-row[data-name='toggle-spreadsheet']`)
          .exists("it shows the builder button");
      });

      test("Can see table builder button when editing post", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click("#post_1 .show-more-actions");
        await click("#post_1 .edit");
        assert.dom("#reply-control").exists();
        await click(".d-editor-button-bar .options");
        await selectKit(".toolbar-popup-menu-options").expand();

        assert
          .dom(`.select-kit-row[data-name='toggle-spreadsheet']`)
          .exists("it shows the builder button");
      });
    }
  );
});
