import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import User from "discourse/models/user";
import { presentUserIds } from "discourse/tests/helpers/presence-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Presence Plugin (new composer actions)",
  function (needs) {
    needs.user({ whisperer: true });
    needs.settings({
      enable_new_composer_actions: true,
    });
    needs.pretender((server, helper) => {
      server.get("/drafts/topic_280.json", function () {
        return helper.response(200, { draft: null });
      });
    });

    test("Uses whisper channel for whispers via actions dropdown", async function (assert) {
      await visit("/t/internationalization-localization/280");

      await click("#topic-footer-buttons .btn.create");
      assert.dom(".d-editor-input").exists("the composer input is visible");

      await fillIn(".d-editor-input", "this is the content of my reply");

      assert.deepEqual(
        presentUserIds("/discourse-presence/reply/280"),
        [User.current().id],
        "publishes reply presence when typing"
      );

      await click(".composer-actions-trigger");
      await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

      assert.deepEqual(
        presentUserIds("/discourse-presence/reply/280"),
        [],
        "removes reply presence"
      );

      assert.deepEqual(
        presentUserIds("/discourse-presence/whisper/280"),
        [User.current().id],
        "adds whisper presence"
      );

      await click("#reply-control button.create");

      assert.deepEqual(
        presentUserIds("/discourse-presence/whisper/280"),
        [],
        "leaves whisper channel when composer closes"
      );
    });
  }
);
