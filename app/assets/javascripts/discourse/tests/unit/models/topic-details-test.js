import { module, test } from "qunit";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

function buildDetails(id, topicParams = {}) {
  const topic = Topic.create(Object.assign({ id }, topicParams));
  return topic.get("details");
}

module("Unit | Model | topic-details", function () {
  test("defaults", function (assert) {
    let details = buildDetails(1234);
    assert.present(details, "the details are present by default");
    assert.ok(!details.get("loaded"), "details are not loaded by default");
  });

  test("updateFromJson", function (assert) {
    let details = buildDetails(1234);

    details.updateFromJson({
      allowed_users: [{ username: "eviltrout" }],
    });

    assert.equal(
      details.get("allowed_users.length"),
      1,
      "it loaded the allowed users"
    );
    assert.containsInstance(details.get("allowed_users"), User);
  });
});

module(
  "Unit | Model | topic-details | notificationReasonText",
  function (hooks) {
    hooks.beforeEach(() => {
      User.resetCurrent(
        User.create({
          username: "eviltrout",
          name: "eviltrout",
          id: 321,
        })
      );
    });

    test("mailing_list_mode enabled for the user", function (assert) {
      User.current().set("mailing_list_mode", true);

      let details = buildDetails(1234);
      details.updateFromJson({
        notification_level: 2,
      });

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.mailing_list_mode")
      );
    });

    test("fallback to regular level translation if reason does not exist", function (assert) {
      let details = buildDetails(1234);
      details.updateFromJson({
        notification_level: 3,
        notifications_reason_id: 999,
      });

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.3")
      );
    });

    test("use _stale notification if user is no longer watching category", function (assert) {
      let details = buildDetails(1234, { category_id: 88 });
      details.updateFromJson({
        notification_level: 2,
        notifications_reason_id: 8,
      });

      User.current().set("tracked_category_ids", [88]);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.2_8")
      );

      details = buildDetails(1234, { category_id: 88 });
      details.updateFromJson({
        notification_level: 2,
        notifications_reason_id: 8,
      });

      User.current().set("tracked_category_ids", []);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.2_8_stale")
      );
    });

    test("use _stale notification if user is no longer tracking category", function (assert) {
      let details = buildDetails(1234, { category_id: 88 });
      details.updateFromJson({
        notification_level: 3,
        notifications_reason_id: 6,
      });

      User.current().set("watched_category_ids", [88]);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.3_6")
      );

      details = buildDetails(1234, { category_id: 88 });
      details.updateFromJson({
        notification_level: 3,
        notifications_reason_id: 6,
      });

      User.current().set("watched_category_ids", []);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.3_6_stale")
      );
    });

    test("use _stale notification if user is no longer watching tag", function (assert) {
      let details = buildDetails(1234, { tags: ["test"] });
      details.updateFromJson({
        notification_level: 3,
        notifications_reason_id: 10,
      });

      User.current().set("watched_tags", ["test"]);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.3_10")
      );

      details = buildDetails(1234, { tags: ["test"] });
      details.updateFromJson({
        notification_level: 3,
        notifications_reason_id: 10,
      });

      User.current().set("watched_tags", []);

      assert.equal(
        details.notificationReasonText,
        I18n.t("topic.notifications.reasons.3_10_stale")
      );
    });
  }
);
