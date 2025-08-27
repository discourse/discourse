import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Composer - Edit conflict (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.user();

      let lastBody;
      needs.pretender((server, helper) => {
        server.post("/drafts.json", (request) => {
          lastBody = request.requestBody;
          return helper.response({ success: true });
        });
      });

      test("Should not send 'original_text' when posting a new reply", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click(".topic-post[data-post-number='1'] button.reply");
        await fillIn(
          ".d-editor-input",
          "hello world hello world hello world hello world hello world"
        );
        assert.false(lastBody.includes("original_text"));
      });

      test("Should send 'original_text' when editing a reply", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click(
          ".topic-post[data-post-number='1'] button.show-more-actions"
        );
        await click(".topic-post[data-post-number='1'] button.edit");
        await fillIn(
          ".d-editor-input",
          "hello world hello world hello world hello world hello world"
        );
        assert.true(lastBody.includes("original_text"));
      });
    }
  );
});
