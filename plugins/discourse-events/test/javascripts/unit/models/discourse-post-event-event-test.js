import { module, test } from "qunit";
import DiscoursePostEventEvent, {
  isWithinEventTimeframe,
} from "../../discourse/models/discourse-post-event-event";

module("Unit | Model | DiscoursePostEventEvent", function () {
  test("maps description fields from API response", function (assert) {
    const event = DiscoursePostEventEvent.create({
      id: 1,
      description: "Visit https://example.com",
      description_html:
        'Visit <a href="https://example.com">https://example.com</a>',
    });

    assert.strictEqual(event.description, "Visit https://example.com");
    assert.strictEqual(
      event.descriptionHtml,
      'Visit <a href="https://example.com">https://example.com</a>'
    );
  });

  test("pastEventTimeframe allows a grace period after the end time", function (assert) {
    const endedRecently = DiscoursePostEventEvent.create({
      id: 1,
      ends_at: moment().subtract(5, "minutes").toISOString(),
    });
    const endedLongAgo = DiscoursePostEventEvent.create({
      id: 2,
      ends_at: moment().subtract(15, "minutes").toISOString(),
    });
    const noEndTime = DiscoursePostEventEvent.create({ id: 3 });

    assert.false(
      endedRecently.pastEventTimeframe,
      "still within the grace period"
    );
    assert.true(endedLongAgo.pastEventTimeframe, "past the grace period");
    assert.false(
      noEndTime.pastEventTimeframe,
      "an event without an end time never ends"
    );
  });

  test("currentlyWithinEventTimeframe opens 30 minutes before the start", function (assert) {
    const notYetOpen = DiscoursePostEventEvent.create({
      id: 1,
      starts_at: moment().add(45, "minutes").toISOString(),
      ends_at: moment().add(2, "hours").toISOString(),
    });
    const earlyAccess = DiscoursePostEventEvent.create({
      id: 2,
      starts_at: moment().add(15, "minutes").toISOString(),
      ends_at: moment().add(2, "hours").toISOString(),
    });

    assert.false(notYetOpen.currentlyWithinEventTimeframe, "45 minutes out");
    assert.true(earlyAccess.currentlyWithinEventTimeframe, "15 minutes out");
  });

  test("currentlyWithinEventTimeframe closes 10 minutes after the end", function (assert) {
    const inProgress = DiscoursePostEventEvent.create({
      id: 1,
      starts_at: moment().subtract(1, "hour").toISOString(),
      ends_at: moment().add(1, "hour").toISOString(),
    });
    const withinGrace = DiscoursePostEventEvent.create({
      id: 2,
      starts_at: moment().subtract(2, "hours").toISOString(),
      ends_at: moment().subtract(5, "minutes").toISOString(),
    });
    const pastGrace = DiscoursePostEventEvent.create({
      id: 3,
      starts_at: moment().subtract(2, "hours").toISOString(),
      ends_at: moment().subtract(15, "minutes").toISOString(),
    });

    assert.true(inProgress.currentlyWithinEventTimeframe, "in progress");
    assert.true(withinGrace.currentlyWithinEventTimeframe, "within grace");
    assert.false(pastGrace.currentlyWithinEventTimeframe, "past grace");
  });

  test("updateFromEvent copies the livestream fields", function (assert) {
    const event = DiscoursePostEventEvent.create({ id: 1 });
    const updated = DiscoursePostEventEvent.create({
      id: 1,
      location: "https://us06web.zoom.us/j/123456789",
      livestream: true,
      livestream_chat_channel_id: 9,
      is_zoom_livestream: true,
    });

    event.updateFromEvent(updated);

    assert.true(event.livestream);
    assert.strictEqual(
      event.livestreamUrl,
      "https://us06web.zoom.us/j/123456789"
    );
    assert.strictEqual(
      event.livestreamChatChannelId,
      9,
      "keeps the chat channel the Zoom entry depends on"
    );
    assert.true(
      event.isZoomLivestream,
      "keeps the flag that decides whether the Zoom entry renders"
    );
  });

  test("updateFromEvent copies description fields", function (assert) {
    const event = DiscoursePostEventEvent.create({ id: 1 });
    const updated = DiscoursePostEventEvent.create({
      id: 1,
      description: "Visit https://example.com",
      description_html:
        'Visit <a href="https://example.com">https://example.com</a>',
    });

    event.updateFromEvent(updated);

    assert.strictEqual(event.description, "Visit https://example.com");
    assert.strictEqual(
      event.descriptionHtml,
      'Visit <a href="https://example.com">https://example.com</a>'
    );
  });

  test("isWithinEventTimeframe returns true for all-day events on the same day", function (assert) {
    const startsAt = moment().startOf("day").toISOString();
    const allDayEvent = DiscoursePostEventEvent.create({
      id: 1,
      starts_at: startsAt,
      ends_at: null,
      all_day: true,
    });

    assert.true(
      isWithinEventTimeframe(
        allDayEvent.allDay,
        allDayEvent.startsAt,
        allDayEvent.endsAt
      ),
      "returns true for all-day events on the same day"
    );
  });

  test("isWithinEventTimeframe returns false for all-day events on a different day", function (assert) {
    const startsAt = moment().add(1, "day").toISOString();
    const allDayEvent = DiscoursePostEventEvent.create({
      id: 2,
      starts_at: startsAt,
      ends_at: null,
      all_day: true,
    });

    assert.false(
      isWithinEventTimeframe(
        allDayEvent.allDay,
        allDayEvent.startsAt,
        allDayEvent.endsAt
      ),
      "returns false for all-day events on a different day"
    );
  });

  test("isWithinEventTimeframe returns true for non-all-day events within the timeframe", function (assert) {
    const startsAt = moment().subtract(15, "minutes").toISOString();
    const endsAt = moment().add(15, "minutes").toISOString();
    const nonAllDayEvent = DiscoursePostEventEvent.create({
      id: 3,
      starts_at: startsAt,
      ends_at: endsAt,
      all_day: false,
    });

    assert.true(
      isWithinEventTimeframe(
        nonAllDayEvent.allDay,
        nonAllDayEvent.startsAt,
        nonAllDayEvent.endsAt
      ),
      "returns true for non-all-day events within the timeframe"
    );
  });
});
