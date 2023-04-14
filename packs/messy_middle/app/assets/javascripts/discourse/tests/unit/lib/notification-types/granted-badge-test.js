import { module, test } from "qunit";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { deepMerge } from "discourse-common/lib/object";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import Notification from "discourse/models/notification";
import I18n from "I18n";
import { setupTest } from "ember-qunit";

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
          badge_id: 44,
          badge_slug: "badge-15-slug",
          badge_name: "Badge 15",
          username: "gg.player",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | granted-badge", function (hooks) {
  setupTest(hooks);

  test("linkHref", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "granted_badge",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/badges/44/badge-15-slug?username=gg.player",
      "links to the badge page and filters by the username"
    );
  });

  test("description", async function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "granted_badge",
      this.siteSettings
    );
    assert.strictEqual(
      director.description,
      I18n.t("notifications.granted_badge", { description: "Badge 15" }),
      "contains the right content"
    );
  });
});
