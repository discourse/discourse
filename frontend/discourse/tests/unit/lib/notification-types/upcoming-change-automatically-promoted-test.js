import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Notification from "discourse/models/notification";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import { i18n } from "discourse-i18n";

function getNotification(data) {
  return Notification.create({
    id: 1,
    user_id: 1,
    notification_type: 42,
    read: false,
    high_priority: false,
    created_at: "2025-01-01T00:00:00.000Z",
    data: data || {
      upcoming_change_names: ["Enable Feature X"],
      upcoming_change_humanized_names: ["Enable Feature X"],
      count: 1,
    },
  });
}

module(
  "Unit | Notification Types | upcoming-change-automatically-promoted",
  function (hooks) {
    setupTest(hooks);

    test("description with single change", function (assert) {
      const notification = getNotification();
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(
        director.description,
        i18n(
          "notifications.upcoming_changes.automatically_promoted.description",
          { changeName: "Enable Feature X" }
        )
      );
    });

    test("description with two changes", function (assert) {
      const notification = getNotification({
        upcoming_change_names: ["enable_feature_x", "enable_feature_y"],
        upcoming_change_humanized_names: [
          "Enable Feature X",
          "Enable Feature Y",
        ],
        count: 2,
      });
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(
        director.description,
        i18n(
          "notifications.upcoming_changes.automatically_promoted.description_two",
          {
            changeName1: "Enable Feature X",
            changeName2: "Enable Feature Y",
          }
        )
      );
    });

    test("description with many changes", function (assert) {
      const notification = getNotification({
        upcoming_change_names: [
          "enable_feature_x",
          "enable_feature_y",
          "enable_feature_z",
          "enable_feature_w",
        ],
        upcoming_change_humanized_names: [
          "Enable Feature X",
          "Enable Feature Y",
          "Enable Feature Z",
          "Enable Feature W",
        ],
        count: 4,
      });
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(
        director.description,
        i18n(
          "notifications.upcoming_changes.automatically_promoted.description_many",
          { changeName: "Enable Feature X", count: 3 }
        )
      );
    });

    test("description with old singular data format", function (assert) {
      const notification = getNotification({
        upcoming_change_humanized_name: "Enable Feature X",
      });
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(
        director.description,
        i18n(
          "notifications.upcoming_changes.automatically_promoted.description",
          { changeName: "Enable Feature X" }
        )
      );
    });

    test("linkHref", function (assert) {
      const notification = getNotification();
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(director.linkHref, "/admin/config/upcoming-changes");
    });

    test("icon", function (assert) {
      const notification = getNotification();
      const director = createRenderDirector(
        notification,
        "upcoming_change_automatically_promoted",
        this.siteSettings
      );
      assert.strictEqual(director.icon, "flask");
    });
  }
);
