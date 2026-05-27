import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { deepMerge } from "discourse/lib/object";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import { i18n } from "discourse-i18n";

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
      i18n("notifications.granted_badge", { description: "Badge 15" }),
      "contains the right content"
    );
  });

  test("linkHref points at the post when the badge was granted for one", function (assert) {
    const notification = getNotification({
      data: { topic_id: 123, post_number: 4 },
    });
    const director = createRenderDirector(
      notification,
      "granted_badge",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/t/123/4",
      "links to the post that earned the badge"
    );
  });

  test("description names the topic when the badge was granted for a post", function (assert) {
    const notification = getNotification({
      data: { topic_id: 123, post_number: 4, topic_title: "A great topic" },
    });
    const director = createRenderDirector(
      notification,
      "granted_badge",
      this.siteSettings
    );
    assert.strictEqual(
      director.description,
      i18n("notifications.granted_badge_for_post", {
        description: "Badge 15",
        topic: "A great topic",
      }),
      "includes the topic title"
    );
  });
});
