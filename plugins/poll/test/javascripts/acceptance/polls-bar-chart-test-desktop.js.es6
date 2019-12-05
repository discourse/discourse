import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Rendering polls with bar charts - desktop", {
  loggedIn: true,
  settings: { poll_enabled: true },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  }
});

test("Polls", async assert => {
  await visit("/t/-/15");

  const polls = find(".poll");

  assert.equal(polls.length, 2, "it should render the polls correctly");

  assert.equal(
    find(".info-number", polls[0]).text(),
    "2",
    "it should display the right number of votes"
  );

  assert.equal(
    find(".info-number", polls[1]).text(),
    "3",
    "it should display the right number of votes"
  );
});

test("Public poll", async assert => {
  await visit("/t/-/14");

  const polls = find(".poll");
  assert.equal(polls.length, 1, "it should render the poll correctly");

  await click("button.toggle-results");

  assert.equal(
    find(".poll-voters:first li").length,
    25,
    "it should display the right number of voters"
  );

  // eslint-disable-next-line
  server.get("/polls/voters.json", () => {
    const body = {
      voters: {
        "68b434ff88aeae7054e42cd05a4d9056": [
          {
            id: 777,
            username: "bruce777",
            avatar_template: "/images/avatar.png",
            name: "Bruce Wayne"
          }
        ]
      }
    };

    return [200, { "Content-Type": "application/json" }, body];
  });

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    26,
    "it should display the right number of voters"
  );
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
      voters: Array.from(new Array(5), (_, i) => ({
        id: 600 + i,
        username: `bruce${600 + i}`,
        avatar_template: "/images/avatar.png",
        name: "Bruce Wayne"
      }))
    };

    return [200, { "Content-Type": "application/json" }, body];
  });

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    30,
    "it should display the right number of voters"
  );
});
