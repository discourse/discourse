import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";

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
      queryAll(".poll-voters:first li").length,
      25,
      "it should display the right number of voters"
    );

    assert.notOk(
      queryAll(".poll-voters:first li:first a").attr("href"),
      "user URL does not exist"
    );

    await click(".poll-voters-toggle-expand:first a");

    assert.equal(
      queryAll(".poll-voters:first li").length,
      35,
      "it should display the right number of voters"
    );
  });
});
