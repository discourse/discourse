import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import form from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Event reminder preferences", function (needs) {
  needs.user();
  needs.settings({ discourse_post_event_enabled: true });

  let savedData;
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout.json", () => {
      const profile = cloneJSON(userFixtures["/u/eviltrout.json"]);
      profile.user.can_edit = true;
      profile.user.user_option.event_reminder_preference = "notification";
      return helper.response(profile);
    });
    server.get("/calendar-subscriptions.json", () =>
      helper.response({ has_subscription: false })
    );
    server.put("/u/eviltrout.json", (request) => {
      savedData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  test("saves the user option from the Calendar tab", async function (assert) {
    await visit("/u/eviltrout/preferences/calendar-subscriptions");
    assert.dom(".event-reminder-preferences select").hasValue("notification");
    await form(".event-reminder-preferences form")
      .field("event_reminder_preference")
      .select("both");
    await form(".event-reminder-preferences form").submit();
    assert.strictEqual(
      savedData.event_reminder_preference,
      "both",
      "uses the user preferences endpoint"
    );
  });
});
