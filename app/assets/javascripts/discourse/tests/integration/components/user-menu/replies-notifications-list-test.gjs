import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import RepliesNotificationsList from "discourse/components/user-menu/replies-notifications-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | user-menu | replies-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });
    });

    test("empty state when there are no notifications", async function (assert) {
      await render(<template><RepliesNotificationsList /></template>);
      assert.dom(".empty-state .empty-state-body").exists();
      assert
        .dom(".empty-state .empty-state-title")
        .hasText(i18n("user.no_notifications_title"));
    });
  }
);
