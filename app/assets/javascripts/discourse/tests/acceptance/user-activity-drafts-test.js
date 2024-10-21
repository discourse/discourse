import { visit } from "@ember/test-helpers";
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
