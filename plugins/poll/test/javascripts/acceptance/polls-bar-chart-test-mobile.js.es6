import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Rendering polls with bar charts - mobile", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({ poll_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/polls/voters.json", () => {
      return helper.response({
        voters: Array.from(new Array(10), (_, i) => ({
          id: 500 + i,
          username: `bruce${500 + i}`,
          avatar_template: "/images/avatar.png",
          name: "Bruce Wayne",
        })),
      });
    });
  });
  needs.hooks.beforeEach(() => {
    clearPopupMenuOptionsCallback();
  });

  test("Public number poll", async function (assert) {
    await visit("/t/-/13");

    const polls = queryAll(".poll");
    assert.equal(polls.length, 1, "it should render the poll correctly");

    await click("button.toggle-results");

    assert.equal(
      queryAll(".poll-voters:nth-of-type(1) li").length,
      25,
      "it should display the right number of voters"
    );

    assert.notOk(
      queryAll(".poll-voters:nth-of-type(1) li:nth-of-type(1) a").attr("href"),
      "user URL does not exist"
    );

    await click(".poll-voters-toggle-expand:nth-of-type(1) a");

    assert.equal(
      queryAll(".poll-voters:nth-of-type(1) li").length,
      35,
      "it should display the right number of voters"
    );
  });
});
