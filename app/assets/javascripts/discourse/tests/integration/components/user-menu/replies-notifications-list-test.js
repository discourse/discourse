import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module(
  "Integration | Component | user-menu | replies-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });
    });

    const template = hbs`<UserMenu::RepliesNotificationsList/>`;

    test("empty state when there are no notifications", async function (assert) {
      await render(template);
      assert.dom(".empty-state .empty-state-body").exists();
      assert.strictEqual(
        query(".empty-state .empty-state-title").textContent.trim(),
        I18n.t("user.no_notifications_title")
      );
    });
  }
);
