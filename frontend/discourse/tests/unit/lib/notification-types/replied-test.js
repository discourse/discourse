import { getOwner } from "@ember/owner";
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
        notification_type: NOTIFICATION_TYPES.replied,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        topic_id: 100,
        post_number: 5,
        slug: "test-topic",
        fancy_title: "Test Topic",
        data: {
          topic_title: "Test Topic",
          original_post_id: 999,
          original_post_type: 1,
          original_username: "replier",
          display_username: "replier",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | replied", function (hooks) {
  setupTest(hooks);

  test("linkHref points at the post for a flat-topic reply", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.linkHref, "/t/test-topic/100/5");
  });

  test("linkHref points at the specific post for a singular nested-topic-bucket reply", function (assert) {
    const notification = getNotification({
      data: { reply_to_post_number: 1 },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.linkHref, "/t/test-topic/100/5");
  });

  test("linkHref points at the specific post for a singular per-post-bucket reply", function (assert) {
    const notification = getNotification({
      data: { reply_to_post_number: 4 },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.linkHref, "/t/test-topic/100/5");
  });

  test("linkHref targets the topic root with sort=new&collapse_replies=true for a consolidated topic-bucket notification", function (assert) {
    const notification = getNotification({
      data: { reply_to_post_number: 1, consolidated_count: 3 },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(
      director.linkHref,
      "/n/test-topic/100?sort=new&collapse_replies=true"
    );
  });

  test("linkHref targets the bucket parent's context with sort=new&collapse_replies=true for a consolidated per-post-bucket notification", function (assert) {
    const notification = getNotification({
      data: { reply_to_post_number: 4, consolidated_count: 2 },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(
      director.linkHref,
      "/n/test-topic/100/4?sort=new&collapse_replies=true"
    );
  });

  test("linkHref is unchanged for flat-topic consolidated notifications", function (assert) {
    // Flat topics never get the bucket fields (regression guard).
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.linkHref, "/t/test-topic/100/5");
  });

  test("label uses replied_consolidated_in_topic for the topic bucket when consolidated", function (assert) {
    const notification = getNotification({
      data: {
        reply_to_post_number: 1,
        consolidated_count: 3,
        display_username: "3 replies",
      },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(
      director.label,
      i18n("notifications.replied_consolidated_in_topic", { count: 3 })
    );
  });

  test("label uses replied_consolidated_to_post for a per-post bucket when consolidated", function (assert) {
    const notification = getNotification({
      data: {
        reply_to_post_number: 4,
        consolidated_count: 2,
        display_username: "2 replies",
      },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(
      director.label,
      i18n("notifications.replied_consolidated_to_post", { count: 2 })
    );
  });

  test("label falls back to display_username for a single (non-consolidated) reply", function (assert) {
    const notification = getNotification({
      data: { reply_to_post_number: 1 },
    });
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.label, "replier");
  });

  test("label falls back to display_username for flat topics (no bucket)", function (assert) {
    const notification = getNotification();
    const director = createRenderDirector(
      notification,
      "replied",
      getOwner(this).lookup("service:site-settings")
    );
    assert.strictEqual(director.label, "replier");
  });
});
