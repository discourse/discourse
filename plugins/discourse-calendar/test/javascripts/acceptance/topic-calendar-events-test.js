import { visit } from "@ember/test-helpers";
import { skip } from "qunit";
import { acceptance, fakeTime } from "discourse/tests/helpers/qunit-helpers";
import eventTopicFixture from "../helpers/event-topic-fixture";
import getEventByText from "../helpers/get-event-by-text";

acceptance("Discourse Calendar - Topic Calendar Events", function (needs) {
  needs.hooks.beforeEach(function () {
    this.clock = fakeTime("2023-09-10T00:00:00", "Europe/Lisbon", true);
  });

  needs.hooks.afterEach(function () {
    this.clock.restore();
  });

  needs.settings({
    calendar_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(eventTopicFixture);
    });
  });

  skip("renders calendar events with fullDay='false'", async (assert) => {
    await visit("/t/-/252");

    assert.dom(getEventByText("Event 1")).exists();
    assert.dom(getEventByText("Event 2")).exists();
  });
});
