import { htmlSafe } from "@ember/template";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import { deepMerge } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.bookmark_reminder,
        read: false,
        high_priority: true,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        data: {
          title: "this is unsafe bookmark title <a>!",
          display_username: "osama",
          bookmark_name: null,
          bookmarkable_url: "/t/sometopic/3232",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | bookmark-reminder", function (hooks) {
  setupTest(hooks);

  test("linkTitle", function (assert) {
    const notification = getNotification({
      data: { bookmark_name: "My awesome bookmark" },
    });
    const director = createRenderDirector(
      notification,
      "bookmark_reminder",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkTitle,
      i18n("notifications.titles.bookmark_reminder_with_name", {
        name: "My awesome bookmark",
      }),
      "content includes the bookmark name when the bookmark has a name"
    );

    delete notification.data.bookmark_name;
    assert.strictEqual(
      director.linkTitle,
      "bookmark reminder",
      "derived from the notification name when there's no bookmark name"
    );
  });

  test("description", function (assert) {
    const notification = getNotification({
      fancy_title: "my fancy title!",
      data: { topic_title: null, title: "custom bookmark title" },
    });
    const director = createRenderDirector(
      notification,
      "bookmark_reminder",
      this.siteSettings
    );
    assert.deepEqual(
      director.description,
      htmlSafe("my fancy title!"),
      "description is the fancy title by default"
    );

    delete notification.fancy_title;
    assert.strictEqual(
      director.description,
      "custom bookmark title",
      "description falls back to the bookmark title if there's no fancy title"
    );
  });

  test("linkHref", function (assert) {
    let notification = getNotification();
    let director = createRenderDirector(
      notification,
      "bookmark_reminder",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/t/this-is-fancy-title/449/113",
      "is a link to the topic that the bookmark belongs to"
    );

    notification = getNotification({
      post_number: null,
      topic_id: null,
      fancy_title: null,
      slug: null,
      data: {
        title: "bookmark from some plugin",
        display_username: "osama",
        bookmark_name: "",
        bookmarkable_url: "/link/to/somewhere",
        bookmarkable_id: 4324,
      },
    });
    director = createRenderDirector(
      notification,
      "bookmark_reminder",
      this.siteSettings
    );
    assert.strictEqual(
      director.linkHref,
      "/link/to/somewhere",
      "falls back to bookmarkable_url"
    );
  });
});
