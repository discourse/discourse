import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { deepMerge } from "discourse-common/lib/object";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { render } from "@ember/test-helpers";
import Notification from "discourse/models/notification";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.granted_badge,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        data: {
          badge_id: 12,
          badge_name: "Tough Guy <a>",
          badge_slug: "tough-guy",
          username: "ossa",
          badge_title: false,
        },
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | granted-badge-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::GrantedBadgeNotificationItem @item={{this.notification}}/>`;

    test("links to the badge page and filters by the username", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const link = query("li a");
      assert.ok(link.href.endsWith("/badges/12/tough-guy?username=ossa"));
    });

    test("displays the right notification content", async function (assert) {
      this.set("notification", getNotification());
      await render(template);
      const div = query("li div");
      assert.strictEqual(
        div.textContent.trim(),
        I18n.t("notifications.granted_badge", {
          description: "Tough Guy <a>",
        }),
        "label is rendered safely"
      );
      assert.ok(!exists("li .notification-label"));
      assert.ok(!exists("li .notification-description"));
    });
  }
);
