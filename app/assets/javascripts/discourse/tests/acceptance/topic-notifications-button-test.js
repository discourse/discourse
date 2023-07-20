import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Topic Notifications button", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.post("/t/280/notifications", () => {
      return helper.response({});
    });
  });

  test("Updating topic notification level", async function (assert) {
    const notificationOptions = selectKit(
      "#topic-footer-buttons .topic-notifications-options"
    );

    await visit("/t/internationalization-localization/280");

    assert.ok(
      notificationOptions.exists(),
      "it should display the notification options button in the topic's footer"
    );

    await notificationOptions.expand();
    await notificationOptions.selectRowByValue("3");

    assert.strictEqual(
      notificationOptions.header().label(),
      "Watching",
      "it should display the right notification level"
    );

    const timelineNotificationOptions = selectKit(
      ".topic-timeline .topic-notifications-options"
    );

    assert.strictEqual(
      timelineNotificationOptions.header().value(),
      "3",
      "it should display the right notification level"
    );

    await timelineNotificationOptions.expand();
    await timelineNotificationOptions.selectRowByValue("0");

    assert.strictEqual(
      timelineNotificationOptions.header().value(),
      "0",
      "it should display the right notification level"
    );

    assert.strictEqual(
      notificationOptions.header().label(),
      "Muted",
      "it should display the right notification level"
    );
  });
});
