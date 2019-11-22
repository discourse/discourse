import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Rendering polls with pie charts - desktop", {
  loggedIn: true,
  settings: { poll_enabled: true, poll_groupable_user_fields: "something" },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  },
  pretend(server, helper) {
    server.get("/polls/grouped_poll_results.json", () => {
      return helper.response({
        grouped_results: [
          {
            group: "Male",
            options: [
              {
                digest: "687a1ccf3c6a260f9aeeb7f68a1d463c",
                html: "This Is",
                votes: 0
              },
              {
                digest: "9377906763a1221d31d656ea0c4a4495",
                html: "A test for sure",
                votes: 1
              },
              {
                digest: "ecf47c65a85a0bb20029072b1b721977",
                html: "Why not give it some more",
                votes: 1
              }
            ]
          }
        ]
      });
    });
  }
});

test("Polls", async assert => {
  await visit("/t/-/topic_with_pie_chart_poll");

  const poll = find(".poll")[0];

  assert.equal(
    find(".info-number", poll)[0].innerHTML,
    "1",
    "it should display the right number of voters"
  );

  assert.equal(
    find(".info-number", poll)[1].innerHTML,
    "2",
    "it should display the right number of votes"
  );

  assert.equal(
    poll.classList.contains("pie"),
    true,
    "pie class is present on poll div"
  );

  assert.equal(
    find(".poll-results-chart", poll).length,
    1,
    "Renders the chart div instead of bar container"
  );

  assert.equal(
    find(".poll-group-by-toggle").text(),
    "Show breakdown",
    "Shows the breakdown button when poll_groupable_user_fields is non-empty"
  );

  await click(".poll-group-by-toggle:first");

  assert.equal(
    find(".poll-group-by-toggle").text(),
    "Hide breakdown",
    "Shows the combine breakdown button after toggle is clicked"
  );

  // Double click to make sure the state toggles back to combined view
  await click(".poll-group-by-toggle:first");
  await click(".poll-group-by-toggle:first");

  assert.equal(
    find(".poll-group-by-toggle").text(),
    "Hide breakdown",
    "Returns to the grouped view, after toggling results shown"
  );
});
