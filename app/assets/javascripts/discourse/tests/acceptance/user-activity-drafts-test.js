import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "../helpers/qunit-helpers";

acceptance("User Activity / Drafts - empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = { drafts: [] };

    server.get("/drafts.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("It renders the empty state panel", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom("div.empty-state").exists();
  });
});

acceptance("User Activity / Drafts - visiting another user", function (needs) {
  const currentUser = "eviltrout";
  const anotherUser = "charlie";

  needs.user();

  test("redirects to the current user drafts page", async function (assert) {
    await visit(`/u/${anotherUser}/activity/drafts`);

    assert.strictEqual(currentURL(), `/u/${currentUser}/activity/drafts`);
  });
});

acceptance("User Activity / Drafts - not signed in", function () {
  test("redirects to the login page", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");

    assert.strictEqual(currentURL(), "/latest");
  });
});
