import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Chat | Email Preferences", function (needs) {
  needs.user();
  needs.settings({
    chat_enabled: true,
  });

  let savedData;
  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      savedData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  test("saves chat_email_frequency when saving email preferences", async function (assert) {
    updateCurrentUser({
      user_option: {
        chat_email_frequency: "when_away",
      },
    });

    await visit("/u/eviltrout/preferences/emails");

    const dropdown = selectKit("#user_chat_email_frequency");
    await dropdown.expand();
    await dropdown.selectRowByValue("never");

    await click(".save-changes");

    assert.strictEqual(
      savedData.chat_email_frequency,
      "never",
      "chat_email_frequency is included in saved data"
    );
  });
});
