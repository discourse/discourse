import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Rendering polls with pie charts", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: true,
    poll_groupable_user_fields: "something",
  });

  test("Displays the pie chart", async function (assert) {
    await visit("/t/-/topic_with_pie_chart_poll");

    assert
      .dom(".poll .poll-info_counts-count:first-child .info-number")
      .hasText("2", "it should display the right number of voters");

    assert
      .dom(".poll .poll-info_counts-count:last-child .info-number")
      .hasText("5", "it should display the right number of votes");

    assert
      .dom(".poll-outer")
      .hasClass("pie", "pie class is present on poll div");

    assert
      .dom(".poll .poll-results-chart")
      .exists({ count: 1 }, "Renders the chart div instead of bar container");
  });
});
