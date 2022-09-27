import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Composer - Messages", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/composer_messages/user_not_seen_in_a_while", () => {
      return helper.response({
        user_count: 1,
        warning_message:
          "The person you are messaging, charlie, hasn’t been seen here in a very long time – about 1 year ago. They may not receive your message. You may wish to seek out alternate methods of contacting charlie.",
      });
    });
  });

  test("Shows warning in composer if user hasn't been seen in a long time.", async function (assert) {
    await visit("/u/charlie");
    await click("button.compose-pm");
    assert.ok(
      !exists(".composer-popup"),
      "composer warning is not shown by default"
    );
    await triggerKeyEvent(".d-editor-input", "keyup", "Space");
    assert.ok(exists(".composer-popup"), "shows composer warning message");
    assert.strictEqual(
      query(".composer-popup h3").innerHTML.trim(),
      "User hasn't been seen in a long time",
      "warning message has correct title"
    );
    assert.strictEqual(
      query(".composer-popup p").innerHTML.trim(),
      "The person you are messaging, charlie, hasn’t been seen here in a very long time – about 1 year ago. They may not receive your message. You may wish to seek out alternate methods of contacting charlie.",
      "warning message has correct body"
    );
  });
});
