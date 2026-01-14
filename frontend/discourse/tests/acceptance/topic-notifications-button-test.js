import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import notificationsTracking from "discourse/tests/helpers/notifications-tracking-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Notifications button", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.post("/t/280/notifications", () => {
      return helper.response({});
    });
  });

  test("Updating topic notification level", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await notificationsTracking().selectLevelId(3);

    assert
      .notificationsTracking()
      .hasSelectedLevelName(
        "watching",
        "displays the right notification level"
      );
  });
});
