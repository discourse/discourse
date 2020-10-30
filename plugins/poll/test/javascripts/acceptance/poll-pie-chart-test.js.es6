import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";

acceptance("Rendering polls with pie charts", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: true,
    poll_groupable_user_fields: "something",
  });

  test("Displays the pie chart", async function (assert) {
    await visit("/t/-/topic_with_pie_chart_poll");

    const poll = queryAll(".poll")[0];

    assert.equal(
      queryAll(".info-number", poll)[0].innerHTML,
      "2",
      "it should display the right number of voters"
    );

    assert.equal(
      queryAll(".info-number", poll)[1].innerHTML,
      "5",
      "it should display the right number of votes"
    );

    assert.equal(
      poll.classList.contains("pie"),
      true,
      "pie class is present on poll div"
    );

    assert.equal(
      queryAll(".poll-results-chart", poll).length,
      1,
      "Renders the chart div instead of bar container"
    );
  });
});
