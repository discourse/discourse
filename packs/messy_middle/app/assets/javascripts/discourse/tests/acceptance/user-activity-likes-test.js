import { acceptance, query } from "../helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import I18n from "I18n";

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
      I18n.t("user_activity.no_likes_title")
    );
  });

  test("When looking at another user's likes page", async function (assert) {
    await visit(`/u/${anotherUser}/activity/likes-given`);
    assert.equal(
      query("div.empty-state span.empty-state-title").innerText,
      I18n.t("user_activity.no_likes_title_others", { username: anotherUser })
    );
  });
});
