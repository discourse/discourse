import { visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance, fakeTime } from "discourse/tests/helpers/qunit-helpers";
import eventTopicFixture from "../helpers/event-topic-fixture";
import getEventByText from "../helpers/get-event-by-text";

function fixtureWithFullDay(fullDay) {
  const fixture = cloneJSON(eventTopicFixture);
  fixture.post_stream.posts[0].cooked =
    fixture.post_stream.posts[0].cooked.replace(
      /data-calendar-full-day="(true|false)"/,
      `data-calendar-full-day="${fullDay}"`
    );
  return response(fixture);
}

acceptance("Topic Calendar Events", function (needs) {
  needs.hooks.beforeEach(function () {
    this.clock = fakeTime("2023-09-10T00:00:00", "Europe/Lisbon", true);
  });

  needs.hooks.afterEach(function () {
    this.clock.restore();
  });

  needs.settings({ calendar_enabled: true });

  test("renders calendar events with fullDay='true'", async function (assert) {
    pretender.get("/t/252.json", () => fixtureWithFullDay("true"));
    await visit("/t/-/252");
    await waitFor(".fc-daygrid-event-harness");

    assert.dom(".fc-daygrid-day").exists("the calendar rendered");
    assert.dom(getEventByText("Event 1")).exists();
    assert.dom(getEventByText("Event 2")).exists();
  });

  test("renders calendar events with fullDay='false'", async function (assert) {
    pretender.get("/t/252.json", () => fixtureWithFullDay("false"));
    await visit("/t/-/252");
    await waitFor(".fc-daygrid-event-harness");

    assert.dom(".fc-daygrid-day").exists("the calendar rendered");
    assert.dom(getEventByText("Event 1")).exists();
    assert.dom(getEventByText("Event 2")).exists();
  });
});
