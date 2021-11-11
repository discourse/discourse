import { acceptance, exists, query } from "../helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import I18n from "I18n";

acceptance("User Activity / Likes - empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { user_actions: [] };

    server.get("/user_actions.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("When looking at own activity it renders the empty state panel", async function (assert) {
    await visit("/u/eviltrout/activity/likes-given");
    assert.ok(exists("div.empty-state"));
  });

  test("When looking at another user activity it renders the 'No activity' message", async function (assert) {
    await visit("/u/charlie/activity/likes-given");
    assert.ok(exists("div.alert-info"));
    assert.strictEqual(
      query("div.alert-info").innerText.trim(),
      I18n.t("user_activity.no_likes_others")
    );
  });
});
