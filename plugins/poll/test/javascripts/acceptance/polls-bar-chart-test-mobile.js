import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

  test("Public number poll", async function (assert) {
    await visit("/t/-/13");

    assert.dom(".poll").exists({ count: 1 }, "renders the poll correctly");

    await click("button.toggle-results");

    assert
      .dom(".poll-voters:nth-of-type(1) li")
      .exists({ count: 25 }, "displays the right number of voters");

    assert
      .dom(".poll-voters:nth-of-type(1) li:nth-of-type(1) a")
      .doesNotHaveAttribute("href", "user URL does not exist");

    await click(".poll-voters-toggle-expand:nth-of-type(1) a");

    assert
      .dom(".poll-voters:nth-of-type(1) li")
      .exists({ count: 35 }, "displays the right number of voters");
  });
});
