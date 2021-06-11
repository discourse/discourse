import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Rendering polls with bar charts - desktop", function (needs) {
  needs.user();
  needs.settings({ poll_enabled: true });
  needs.hooks.beforeEach(() => {
    clearPopupMenuOptionsCallback();
  });
  needs.pretender((server, helper) => {
    server.get("/polls/voters.json", (request) => {
      let body = {};
      if (
        request.queryParams.option_id === "68b434ff88aeae7054e42cd05a4d9056"
      ) {
        body = {
          voters: {
            "68b434ff88aeae7054e42cd05a4d9056": [
              {
                id: 777,
                username: "bruce777",
                avatar_template: "/images/avatar.png",
                name: "Bruce Wayne",
              },
            ],
          },
        };
      } else {
        body = {
          voters: Array.from(new Array(5), (_, i) => ({
            id: 600 + i,
            username: `bruce${600 + i}`,
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
          })),
        };
      }
      return helper.response(body);
    });
  });

  test("Polls", async function (assert) {
    await visit("/t/-/15");

    const polls = queryAll(".poll");

    assert.equal(polls.length, 2, "it should render the polls correctly");

    assert.equal(
      queryAll(".info-number", polls[0]).text(),
      "2",
      "it should display the right number of votes"
    );

    assert.equal(
      queryAll(".info-number", polls[1]).text(),
      "3",
      "it should display the right number of votes"
    );
  });

  test("Public poll", async function (assert) {
    await visit("/t/-/14");

    const polls = queryAll(".poll");
    assert.equal(polls.length, 1, "it should render the poll correctly");

    await click("button.toggle-results");

    assert.equal(
      queryAll(".poll-voters:nth-of-type(1) li").length,
      25,
      "it should display the right number of voters"
    );

    await click(".poll-voters-toggle-expand:nth-of-type(1) a");

    assert.equal(
      queryAll(".poll-voters:nth-of-type(1) li").length,
      26,
      "it should display the right number of voters"
    );
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
      30,
      "it should display the right number of voters"
    );
  });
});
