import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { deepMerge } from "discourse/lib/object";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";

function getNotification(overrides = {}) {
  return Notification.create(
    deepMerge(
      {
        id: 11,
        user_id: 1,
        notification_type: NOTIFICATION_TYPES.group_mentioned,
        read: false,
        high_priority: false,
        created_at: "2022-07-01T06:00:32.173Z",
        post_number: 113,
        topic_id: 449,
        fancy_title: "This is fancy title &lt;a&gt;!",
        slug: "this-is-fancy-title",
        acting_user_name: "Osama Obama",
        data: {
          topic_title: "this is title before it becomes fancy <a>!",
          original_post_id: 112,
          original_post_type: 1,
          original_username: "kolary",
          original_name: "Osama Obama",
          display_username: "osama",
          display_name: "Osama Obama",
          group_id: 333,
          group_name: "hikers",
        },
      },
      overrides
    )
  );
}

module("Unit | Notification Types | group-mentioned", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "service:site-settings",
      class extends Service {
        prioritize_full_name_in_ux = false;
      }
    );

    this.siteSettings = this.owner.lookup("service:site-settings");
  });

  test("label", function (assert) {
    const notification = getNotification();

    const director = createRenderDirector(
      notification,
      "group_mentioned",
      this.siteSettings
    );

    assert.strictEqual(
      director.label,
      "osama @hikers",
      "contains the user's username who mentioned and the mentioned group"
    );
  });

  test("label uses the user's name when prioritize_username_in_ux is false", function (assert) {
    this.siteSettings.prioritize_full_name_in_ux = true;

    const notification = getNotification();

    const director = createRenderDirector(
      notification,
      "group_mentioned",
      this.siteSettings
    );

    assert.strictEqual(
      director.label,
      "Osama Obama @hikers",
      "contains the user's name who mentioned and the mentioned group"
    );
  });
});
