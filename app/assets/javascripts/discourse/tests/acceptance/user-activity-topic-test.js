import { acceptance, exists, queryAll } from "../helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import userFixtures from "../fixtures/user-fixtures";

acceptance("User Activity / Topics - bulk actions", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/topics/created-by/:username.json", () => {
      return helper.response(userFixtures["/topics/created-by/eviltrout.json"]);
    });

    server.put("/topics/bulk", () => {
      return helper.response({ topic_ids: [7764, 9318] });
    });
  });

  test("bulk topic closing works", async function (assert) {
    await visit("/u/charlie/activity/topics");

    await click("button.bulk-select");
    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);
    await click("button.bulk-select-actions");

    await click("div.bulk-buttons button:nth-child(2)"); // the Close Topics button

    assert.notOk(
      exists("div.bulk-buttons"),
      "The bulk actions modal was closed"
    );
  });
});

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
