import { acceptance, exists } from "../helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("User Activity / Topics - empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = {
      topic_list: {
        topics: [],
      },
    };

    server.get("/topics/created-by/:username.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("It renders the empty state panel", async function (assert) {
    await visit("/u/charlie/activity/topics");
    assert.ok(exists("div.empty-state"));
  });
});
