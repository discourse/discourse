import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "../fixtures/user-fixtures";
import { acceptance, queryAll } from "../helpers/qunit-helpers";

acceptance("User Activity / Read - bulk actions", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/read.json", () => {
      return helper.response(userFixtures["/topics/created-by/eviltrout.json"]);
    });

    server.put("/topics/bulk", () => {
      return helper.response({ topic_ids: [7764, 9318] });
    });
  });

  test("bulk topic closing works", async function (assert) {
    await visit("/u/charlie/activity/read");

    await click("button.bulk-select");
    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);
    await click(".bulk-select-topics-dropdown-trigger");
    await click(".dropdown-menu__item .close-topics");

    assert
      .dom("div.bulk-buttons")
      .doesNotExist("The bulk actions modal was closed");
  });
});

acceptance("User Activity / Read - empty state", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const emptyResponse = {
      topic_list: {
        topics: [],
      },
    };

    server.get("/read.json", () => {
      return helper.response(emptyResponse);
    });
  });

  test("It renders the empty state panel", async function (assert) {
    await visit("/u/charlie/activity/read");
    assert.dom("div.empty-state").exists();
  });
});
