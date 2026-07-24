import { triggerKeyEvent, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(
  "Keyboard Shortcuts - Authenticated Users (new composer actions)",
  function (needs) {
    needs.user();
    needs.settings({
      enable_new_composer_actions: true,
    });

    module("context aware create new shortcuts", function () {
      test("C key opens composer in new topic mode from topics list", async function (assert) {
        await visit("/");
        await triggerKeyEvent(document, "keypress", "C");

        assert
          .dom(".composer-action-create-topic .composer-actions-trigger")
          .includesText(
            i18n("composer.composer_actions.create_topic.label"),
            "composer shows create topic title"
          );
      });

      test("C key opens composer in new PM mode from messages list", async function (assert) {
        await visit("/my/messages");
        await triggerKeyEvent(document, "keypress", "C");

        assert
          .dom(".composer-action-private-message .composer-actions-trigger")
          .includesText(
            i18n("composer.composer_actions.create_personal_message.label"),
            "composer shows create message title"
          );
      });

      test("C key opens composer in new PM mode from PM topic", async function (assert) {
        await visit("/t/pm-for-testing/12");
        await triggerKeyEvent(document, "keypress", "C");

        assert
          .dom(".composer-action-private-message .composer-actions-trigger")
          .includesText(
            i18n("composer.composer_actions.create_personal_message.label"),
            "composer shows create message title"
          );
      });
    });
  }
);
