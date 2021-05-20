import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Poll breakdown", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: true,
    poll_groupable_user_fields: "something",
  });
  needs.hooks.beforeEach(() => clearPopupMenuOptionsCallback());
  needs.pretender((server, helper) => {
    server.get("/polls/grouped_poll_results.json", () =>
      helper.response({
        grouped_results: [
          {
            group: "Engineering",
            options: [
              {
                digest: "687a1ccf3c6a260f9aeeb7f68a1d463c",
                html: "This Is",
                votes: 1,
              },
              {
                digest: "9377906763a1221d31d656ea0c4a4495",
                html: "A test for sure",
                votes: 1,
              },
              {
                digest: "ecf47c65a85a0bb20029072b1b721977",
                html: "Why not give it some more",
                votes: 1,
              },
            ],
          },
          {
            group: "Marketing",
            options: [
              {
                digest: "687a1ccf3c6a260f9aeeb7f68a1d463c",
                html: "This Is",
                votes: 1,
              },
              {
                digest: "9377906763a1221d31d656ea0c4a4495",
                html: "A test for sure",
                votes: 1,
              },
              {
                digest: "ecf47c65a85a0bb20029072b1b721977",
                html: "Why not give it some more",
                votes: 1,
              },
            ],
          },
        ],
      })
    );
  });

  test("Displaying the poll breakdown modal", async function (assert) {
    await visit("/t/-/topic_with_pie_chart_poll");

    assert.equal(
      queryAll(".poll-show-breakdown").text(),
      "Show breakdown",
      "shows the breakdown button when poll_groupable_user_fields is non-empty"
    );

    await click(".poll-show-breakdown");

    assert.equal(
      queryAll(".poll-breakdown-total-votes")[0].textContent.trim(),
      "2 votes",
      "display the correct total vote count"
    );

    assert.equal(
      queryAll(".poll-breakdown-chart-container").length,
      2,
      "renders a chart for each of the groups in group_results response"
    );

    assert.ok(
      queryAll(".poll-breakdown-chart-container > canvas")[0].$chartjs,
      "$chartjs is defined on the pie charts"
    );
  });

  test("Changing the display mode from percentage to count", async function (assert) {
    await visit("/t/-/topic_with_pie_chart_poll");
    await click(".poll-show-breakdown");

    assert.equal(
      queryAll(".poll-breakdown-option-count")[0].textContent.trim(),
      "40.0%",
      "displays the correct vote percentage"
    );

    await click(".modal-tabs .count");

    assert.equal(
      queryAll(".poll-breakdown-option-count")[0].textContent.trim(),
      "2",
      "displays the correct vote count"
    );

    await click(".modal-tabs .percentage");

    assert.equal(
      queryAll(".poll-breakdown-option-count:last")[0].textContent.trim(),
      "20.0%",
      "displays the percentage again"
    );
  });
});
