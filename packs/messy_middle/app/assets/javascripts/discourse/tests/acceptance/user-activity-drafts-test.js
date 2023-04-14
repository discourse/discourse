import { acceptance, exists } from "../helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

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
    assert.ok(exists("div.empty-state"));
  });
});
