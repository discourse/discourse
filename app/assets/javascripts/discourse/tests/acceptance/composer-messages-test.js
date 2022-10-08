import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Composer - Messages", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/composer_messages/user_not_seen_in_a_while", () => {
      return helper.response({
        user_count: 1,
        usernames: ["charlie"],
        time_ago: "1 year ago",
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
    assert.ok(
      query(".composer-popup").innerHTML.includes(
        I18n.t("composer.user_not_seen_in_a_while.single", {
          usernames: ['<a class="mention" href="/u/charlie">@charlie</a>'],
          time_ago: "1 year ago",
        })
      ),
      "warning message has correct body"
    );
  });
});
