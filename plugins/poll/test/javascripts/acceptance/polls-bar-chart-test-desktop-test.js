import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Rendering polls with bar charts - desktop", function (needs) {
  needs.user();
  needs.settings({ poll_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/polls/voters.json", (request) => {
      if (
        request.queryParams.option_id === "68b434ff88aeae7054e42cd05a4d9056"
      ) {
        return helper.response({
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
        });
      } else {
        return helper.response({
          voters: Array.from(new Array(5), (_, i) => ({
            id: 600 + i,
            username: `bruce${600 + i}`,
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne",
          })),
        });
      }
    });
  });

  test("Polls", async function (assert) {
    await visit("/t/-/15");
    assert.dom(".poll").exists({ count: 2 }, "renders the polls correctly");

    const polls = document.querySelectorAll(".poll");
    assert
      .dom(".info-number", polls[0])
      .hasText("2", "displays the right number of votes");
    assert
      .dom(".info-number", polls[1])
      .hasText("3", "displays the right number of votes");
  });

  test("Public poll", async function (assert) {
    await visit("/t/-/14");
    assert.dom(".poll").exists({ count: 1 }, "renders the poll correctly");

    await click("button.toggle-results");
    assert
      .dom(".poll-voters li")
      .exists({ count: 25 }, "displays the right number of voters");

    await click(".poll-voters-toggle-expand");
    assert
      .dom(".poll-voters li")
      .exists({ count: 26 }, "displays the right number of voters");
  });

  test("Public number poll", async function (assert) {
    await visit("/t/-/13");
    assert.dom(".poll").exists({ count: 1 }, "renders the poll correctly");

    await click("button.toggle-results");
    assert
      .dom(".poll-info_counts-count .info-number")
      .hasText("35", "displays the right number of voters");
  });
});
