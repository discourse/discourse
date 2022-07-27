import {
  acceptance,
  count,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Rendering polls with pie charts", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: true,
    poll_groupable_user_fields: "something",
  });

  test("Displays the pie chart", async function (assert) {
    await visit("/t/-/topic_with_pie_chart_poll");

    const poll = query(".poll");

    assert.strictEqual(
      query(".info-number", poll).innerHTML,
      "2",
      "it should display the right number of voters"
    );

    assert.strictEqual(
      poll.querySelectorAll(".info-number")[1].innerHTML,
      "5",
      "it should display the right number of votes"
    );

    assert.strictEqual(
      poll.classList.contains("pie"),
      true,
      "pie class is present on poll div"
    );

    assert.strictEqual(
      count(".poll-results-chart", poll),
      1,
      "Renders the chart div instead of bar container"
    );
  });
});
