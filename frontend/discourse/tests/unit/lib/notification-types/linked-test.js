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
        notification_type: NOTIFICATION_TYPES.linked,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        fancy_title: "The topic that did the linking",
        slug: "the-topic-that-did-the-linking",
        topic_id: 22,
        data: {
          topic_title: "The topic that did the linking",
          original_post_id: 3294,
          original_post_type: 1,
          original_username: "linkerman",
          display_username: "linkerman",
          linked_topics: [{ topic_id: 5, title: "My first topic" }],
          linked_topics_count: 1,
        },
      },
      overrides
    )
  );
}

function directorFor(notification, siteSettings) {
  return createRenderDirector(notification, "linked", siteSettings);
}

module("Unit | Notification Types | linked", function (hooks) {
  setupTest(hooks);

  test("names the linked topic rather than the linking one", function (assert) {
    const director = directorFor(getNotification(), this.siteSettings);
    assert.strictEqual(
      director.description,
      "My first topic",
      "shows the recipient's own topic"
    );
  });

  test("names the first topic and counts the rest", function (assert) {
    // One post linking several of the recipient's topics still produces a
    // single notification, and the description is one clamped line, so the
    // remainder is reported as a count.
    const notification = getNotification({
      data: {
        linked_topics: [
          { topic_id: 5, title: "My first topic" },
          { topic_id: 6, title: "My second topic" },
        ],
        linked_topics_count: 3,
      },
    });
    const director = directorFor(notification, this.siteSettings);

    assert.strictEqual(
      director.description,
      i18n("notifications.linked_topics_with_others", {
        topic: "My first topic",
        count: 2,
      }),
      "names one topic and counts the others"
    );
  });

  test("uses the singular form for exactly one other topic", function (assert) {
    const notification = getNotification({
      data: {
        linked_topics: [
          { topic_id: 5, title: "My first topic" },
          { topic_id: 6, title: "My second topic" },
        ],
        linked_topics_count: 2,
      },
    });
    const director = directorFor(notification, this.siteSettings);

    assert.strictEqual(
      director.description,
      i18n("notifications.linked_topics_with_others", {
        topic: "My first topic",
        count: 1,
      }),
      "counts a single remaining topic"
    );
  });

  test("counts topics beyond the stored ones", function (assert) {
    // The backend caps how many titles it stores but keeps the true total,
    // so the count comes from linked_topics_count, not the array length.
    const notification = getNotification({
      data: {
        linked_topics: [
          { topic_id: 5, title: "My first topic" },
          { topic_id: 6, title: "My second topic" },
        ],
        linked_topics_count: 9,
      },
    });
    const director = directorFor(notification, this.siteSettings);

    assert.strictEqual(
      director.description,
      i18n("notifications.linked_topics_with_others", {
        topic: "My first topic",
        count: 8,
      }),
      "reports every uncounted topic, not just the stored ones"
    );
  });

  test("falls back to the linking topic when no linked topics were recorded", function (assert) {
    // Notifications created before this data was stored have to keep
    // rendering.
    const notification = getNotification({
      data: { linked_topics: null, linked_topics_count: null },
    });
    const director = directorFor(notification, this.siteSettings);

    // The base class returns the linking topic's fancy_title wrapped for safe
    // HTML rendering, so compare the rendered text rather than the wrapper.
    assert.strictEqual(
      director.description.toString(),
      "The topic that did the linking",
      "uses the previous behaviour"
    );
  });
});
