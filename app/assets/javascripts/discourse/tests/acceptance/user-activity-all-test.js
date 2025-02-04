import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { i18n } from "discourse-i18n";
import { acceptance } from "../helpers/qunit-helpers";

acceptance("User Activity / All - empty state", function (needs) {
  const currentUser = "eviltrout";
  const anotherUser = "charlie";
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { user_actions: [] };

    server.get("/user_actions.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("When looking at own activity page", async function (assert) {
    await visit(`/u/${currentUser}/activity`);
    assert
      .dom("div.empty-state span.empty-state-title")
      .hasText(i18n("user_activity.no_activity_title"));
  });

  test("When looking at another user's activity page", async function (assert) {
    await visit(`/u/${anotherUser}/activity`);
    assert
      .dom("div.empty-state span.empty-state-title")
      .hasText(i18n("user_activity.no_activity_title")); // the same title as when looking at own page
  });
});
