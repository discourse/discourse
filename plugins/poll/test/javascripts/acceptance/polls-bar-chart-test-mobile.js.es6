import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Rendering polls with bar charts - mobile", {
  loggedIn: true,
  mobileView: true,
  settings: { poll_enabled: true },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  }
});

test("Public number poll", async assert => {
  await visit("/t/-/13");

  const polls = find(".poll");
  assert.equal(polls.length, 1, "it should render the poll correctly");

  await click("button.toggle-results");

  assert.equal(
    find(".poll-voters:first li").length,
    25,
    "it should display the right number of voters"
  );

  assert.notOk(
    find(".poll-voters:first li:first a").attr("href"),
    "user URL does not exist"
  );

  // eslint-disable-next-line
  server.get("/polls/voters.json", () => {
    const body = {
      voters: Array.from(new Array(10), (_, i) => ({
        id: 500 + i,
        username: `bruce${500 + i}`,
        avatar_template: "/images/avatar.png",
        name: "Bruce Wayne"
      }))
    };

    return [200, { "Content-Type": "application/json" }, body];
  });

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    35,
    "it should display the right number of voters"
  );
});
