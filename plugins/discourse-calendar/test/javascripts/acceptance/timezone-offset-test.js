import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, fakeTime } from "discourse/tests/helpers/qunit-helpers";
import eventTopicFixture from "../helpers/event-topic-fixture";
import getEventByText from "../helpers/get-event-by-text";

function getRoundedPct(marginString) {
  return Math.round(marginString.match(/(\d+(\.\d+)?)%/)[1]);
}

function setupClock(needs) {
  needs.hooks.beforeEach(function () {
    this.clock = fakeTime("2023-09-10T00:00:00", "Australia/Brisbane", true);
  });

  needs.hooks.afterEach(function () {
    this.clock.restore();
  });
}

acceptance("Discourse Calendar - Timezone Offset", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(eventTopicFixture);
    });
  });

  test("doesn't apply an offset for events in the same timezone", async (assert) => {
    await visit("/t/-/252");

    const eventElement = getEventByText("Lisbon");

    assert.strictEqual(eventElement.style.marginLeft, "");
    assert.strictEqual(eventElement.style.marginRight, "");
  });

  test("applies the correct offset for events that extend into the next day", async (assert) => {
    await visit("/t/-/252");

    const eventElement = getEventByText("Cordoba");

    assert.strictEqual(getRoundedPct(eventElement.style.marginLeft), 8); // ( ( 1 - (-3) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement.style.marginRight), 42); // ( ( 24 - ( 1 - (-3) ) ) / 24 ) * 50%
  });

  test("applies the correct offset for events that start on the previous day", async (assert) => {
    await visit("/t/-/252");

    const eventElement = getEventByText("Tokyo");

    assert.strictEqual(getRoundedPct(eventElement.style.marginLeft), 22); // ( ( 24 - ( 9 - 1 ) ) / 24 ) * 33.33%
    assert.strictEqual(getRoundedPct(eventElement.style.marginRight), 11); // ( ( 9 - 1 ) / 24 ) * 33.33%
  });

  test("applies the correct offset for multiline events", async (assert) => {
    await visit("/t/-/252");

    const eventElement = getEventByText("Moscow");

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 46); // ( ( 24 - ( 1 - (-1) ) ) / 24 ) * 50%
    assert.strictEqual(eventElement[0].style.marginRight, "");

    assert.strictEqual(eventElement[1].style.marginLeft, "");
    assert.strictEqual(getRoundedPct(eventElement[1].style.marginRight), 8); // ( ( 1 - (-1) ) / 24 ) * 100%
  });
});

acceptance("Discourse Calendar - Splitted Grouped Events", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
    split_grouped_events_by_timezone_threshold: 0,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(eventTopicFixture);
    });
  });

  test("splits holidays events by timezone", async (assert) => {
    await visit("/t/-/252");

    const eventElement = document.querySelectorAll(
      ".fc-day-grid-event.grouped-event"
    );
    assert.strictEqual(eventElement.length, 3);

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 13); // ( ( 1 - (-5) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[0].style.marginRight), 38); // ( ( 24 - ( 1 - (-5) ) ) / 24 ) * 50%

    assert.strictEqual(getRoundedPct(eventElement[1].style.marginLeft), 15); // ( ( 1 - (-6) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[1].style.marginRight), 35); // ( ( 24 - ( 1 - (-6) ) ) / 24 ) * 50%

    assert.strictEqual(getRoundedPct(eventElement[2].style.marginLeft), 17); // ( ( 1 - (-7) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[2].style.marginRight), 33); // ( ( 24 - ( 1 - (-7) ) ) / 24 ) * 50%
  });
});

acceptance("Discourse Calendar - Grouped Events", function (needs) {
  setupClock(needs);

  needs.settings({
    calendar_enabled: true,
    enable_timezone_offset_for_calendar_events: true,
    default_timezone_offset_user_option: true,
    split_grouped_events_by_timezone_threshold: 2,
  });

  needs.pretender((server, helper) => {
    server.get("/t/252.json", () => {
      return helper.response(eventTopicFixture);
    });
  });

  test("groups holidays events according to threshold", async (assert) => {
    await visit("/t/-/252");

    const eventElement = document.querySelectorAll(
      ".fc-day-grid-event.grouped-event"
    );
    assert.strictEqual(eventElement.length, 1);

    assert.strictEqual(getRoundedPct(eventElement[0].style.marginLeft), 15); // ( ( 1 - (-6) ) / 24 ) * 50%
    assert.strictEqual(getRoundedPct(eventElement[0].style.marginRight), 35); // ( ( 24 - ( 1 - (-6) ) ) / 24 ) * 50%
  });
});
