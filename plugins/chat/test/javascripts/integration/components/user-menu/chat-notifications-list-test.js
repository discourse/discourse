import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import I18n from "I18n";

module(
  "Integration | Component | user-menu | chat-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });
    });

    const template = hbs`<UserMenu::ChatNotificationsList/>`;

    test("empty state when there are no notifications", async function (assert) {
      await render(template);
      assert.true(exists(".empty-state .empty-state-body"));
      assert.strictEqual(
        query(".empty-state .empty-state-title").textContent.trim(),
        I18n.t("user_menu.no_chat_notifications_title")
      );
    });
  }
);
