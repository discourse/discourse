import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { acceptance, fakeTime } from "discourse/tests/helpers/qunit-helpers";
import eventTopicFixture from "../helpers/event-topic-fixture";

acceptance("Discourse Calendar - Topic Calendar Holidays", function (needs) {
  needs.hooks.beforeEach(function () {
    this.clock = fakeTime("2023-12-10T00:00:00", "America/Los_Angeles", true);
  });

  needs.hooks.afterEach(function () {
    this.clock.restore();
  });

  needs.settings({
    calendar_enabled: true,
  });

  needs.pretender((server, helper) => {
    const clonedEventTopicFixture = cloneJSON(eventTopicFixture);

    clonedEventTopicFixture.post_stream.posts[0].calendar_details = [
      {
        type: "grouped",
        from: "2023-12-25T05:00:00.000Z",
        timezone: "Europe/Rome",
        name: "Natale",
        users: [
          {
            username: "gmt+1_user",
            timezone: "Europe/Rome",
          },
        ],
      },
    ];
    server.get("/t/252.json", () => {
      return helper.response(clonedEventTopicFixture);
    });
  });

  test("renders calendar holidays with fullDay='true'", async (assert) => {
    await visit("/t/-/252");

    assert
      .dom(".fc-week:nth-child(5) .fc-content-skeleton tbody td:first-child")
      .hasClass(
        "fc-event-container",
        "Italian Christmas Day is displayed on Monday 2023-12-25"
      );
  });
});
