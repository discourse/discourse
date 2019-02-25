import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import Fixtures from "fixtures/poll";

acceptance("Rendering polls - mobile", {
  loggedIn: true,
  mobileView: true,
  settings: { poll_enabled: true },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  }
});

test("Public number poll", async assert => {
  // prettier-ignore
  server.get("/t/13.json", () => { // eslint-disable-line no-undef
    return [200, { "Content-Type": "application/json" }, Fixtures["t/13.json"]];
  });

  // prettier-ignore
  server.get("/polls/voters.json", request => { // eslint-disable-line no-undef
    let body = {};

    if (
      request.queryParams.post_id === "16" &&
      request.queryParams.poll_name === "poll" &&
      request.queryParams.page === "1"
    ) {
      body = Fixtures["/polls/voters.json?page=1"];
    } else if (
      request.queryParams.post_id === "16" &&
      request.queryParams.poll_name === "poll"
    ) {
      body = Fixtures["/polls/voters.json"];
    }

    return [200, { "Content-Type": "application/json" }, body];
  });

  await visit("/t/this-is-a-topic-for-testing-number-poll/13");

  const polls = find(".poll");
  assert.equal(polls.length, 1, "it should render the poll correctly");

  await click("button.toggle-results");

  assert.equal(
    find(".poll-voters:first li").length,
    25,
    "it should display the right number of voters"
  );

  assert.ok(
    find(".poll-voters:first li:first a").attr("href"),
    "user URL exists"
  );

  await click(".poll-voters-toggle-expand:first a");

  assert.equal(
    find(".poll-voters:first li").length,
    35,
    "it should display the right number of voters"
  );
});
