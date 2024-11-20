import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | user-menu | other-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(() => {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });
    });

    const template = hbs`<UserMenu::OtherNotificationsList/>`;

    test("empty state when there are no notifications", async function (assert) {
      await render(template);
      assert.dom(".empty-state .empty-state-body").exists();
      assert.strictEqual(
        query(".empty-state .empty-state-title").textContent.trim(),
        i18n("user.no_other_notifications_title")
      );
    });
  }
);
