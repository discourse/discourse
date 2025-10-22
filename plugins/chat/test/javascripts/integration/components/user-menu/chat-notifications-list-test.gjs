import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ChatNotificationsList from "discourse/plugins/chat/discourse/components/user-menu/chat-notifications-list";

module(
  "Integration | Component | user-menu | chat-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });
    });

    const template = <template><ChatNotificationsList /></template>;

    test("empty state when there are no notifications", async function (assert) {
      await render(template);
      assert.dom(".empty-state .empty-state__body").exists();
      assert
        .dom(".empty-state .empty-state__title")
        .hasText(i18n("user_menu.no_chat_notifications_title"));
    });
  }
);
