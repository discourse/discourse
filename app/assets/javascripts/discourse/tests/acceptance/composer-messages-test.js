import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
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

acceptance("Composer - Messages - Cannot see group", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/composer/mentions", () => {
      return helper.response({
        users: [],
        user_reasons: {},
        groups: {
          staff: { user_count: 30 },
          staff2: { user_count: 30, notified_count: 10 },
        },
        group_reasons: { staff: "not_allowed", staff2: "some_not_allowed" },
        max_users_notified_per_group_mention: 100,
      });
    });
  });

  test("Shows warning in composer if group hasn't been invited", async function (assert) {
    await visit("/t/130");
    await click("button.create");
    assert.ok(
      !exists(".composer-popup"),
      "composer warning is not shown by default"
    );
    await fillIn(".d-editor-input", "Mention @staff");
    assert.ok(exists(".composer-popup"), "shows composer warning message");
    assert.ok(
      query(".composer-popup").innerHTML.includes(
        I18n.t("composer.cannot_see_group_mention.not_allowed", {
          group: "staff",
        })
      ),
      "warning message has correct body"
    );
  });

  test("Shows warning in composer if group hasn't been invited, but some members have access already", async function (assert) {
    await visit("/t/130");
    await click("button.create");
    assert.ok(
      !exists(".composer-popup"),
      "composer warning is not shown by default"
    );
    await fillIn(".d-editor-input", "Mention @staff2");
    assert.ok(exists(".composer-popup"), "shows composer warning message");
    assert.ok(
      query(".composer-popup").innerHTML.includes(
        I18n.t("composer.cannot_see_group_mention.some_not_allowed", {
          group: "staff2",
          count: 10,
        })
      ),
      "warning message has correct body"
    );
  });
});
