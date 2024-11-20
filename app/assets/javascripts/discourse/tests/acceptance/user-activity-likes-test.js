import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { i18n } from "discourse-i18n";
import { acceptance, query } from "../helpers/qunit-helpers";

acceptance("User Activity / Likes - empty state", function (needs) {
  const currentUser = "eviltrout";
  const anotherUser = "charlie";
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { user_actions: [] };

    server.get("/user_actions.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("When looking at own likes page", async function (assert) {
    await visit(`/u/${currentUser}/activity/likes-given`);
    assert.equal(
      query("div.empty-state span.empty-state-title").innerText,
      i18n("user_activity.no_likes_title")
    );
  });

  test("When looking at another user's likes page", async function (assert) {
    await visit(`/u/${anotherUser}/activity/likes-given`);
    assert.equal(
      query("div.empty-state span.empty-state-title").innerText,
      i18n("user_activity.no_likes_title_others", { username: anotherUser })
    );
  });
});
