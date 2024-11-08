import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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

    assert.true(
      notificationOptions.exists(),
      "displays the notification options button in the topic's footer"
    );

    await notificationOptions.expand();
    await notificationOptions.selectRowByValue("3");

    assert.strictEqual(
      notificationOptions.header().label(),
      "Watching",
      "displays the right notification level"
    );
  });
});
