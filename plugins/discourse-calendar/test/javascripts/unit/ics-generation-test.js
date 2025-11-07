import { module, test } from "qunit";
import {
  bbcodeAttributeDecode,
  bbcodeAttributeEncode,
} from "discourse/lib/bbcode-attributes";
import { generateIcsData } from "discourse/lib/download-calendar";

module("Unit | Discourse Calendar | ICS Generation", function () {
  test("generates valid ICS data", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("BEGIN:VCALENDAR"), "contains VCALENDAR");
    assert.true(icsData.includes("VERSION:2.0"), "contains version");
    assert.true(icsData.includes("BEGIN:VEVENT"), "contains VEVENT");
    assert.true(icsData.includes("SUMMARY:Test Event"), "contains title");
    assert.true(icsData.includes("DTSTART:"), "contains start time");
    assert.true(icsData.includes("DTEND:"), "contains end time");
    assert.true(icsData.includes("END:VEVENT"), "closes VEVENT");
    assert.true(icsData.includes("END:VCALENDAR"), "closes VCALENDAR");
  });

  test("includes location when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { location: "Test Location" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("LOCATION:Test Location"),
      "includes location"
    );
  });

  test("includes description when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { details: "Test Description" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("DESCRIPTION:Test Description"),
      "includes description"
    );
  });

  test("includes recurrence rule when provided", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { rrule: "FREQ=WEEKLY;BYDAY=MO" };

    const icsData = generateIcsData(title, dates, options);

    assert.true(
      icsData.includes("RRULE:FREQ=WEEKLY;BYDAY=MO"),
      "includes rrule"
    );
  });

  test("handles multiple dates", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
      {
        startsAt: "2025-12-08T12:00:00Z",
        endsAt: "2025-12-08T13:00:00Z",
      },
    ];
    const options = {};

    const icsData = generateIcsData(title, dates, options);

    // Count how many VEVENT blocks there are
    const eventCount = (icsData.match(/BEGIN:VEVENT/g) || []).length;
    assert.strictEqual(eventCount, 2, "creates two VEVENT blocks");
  });

  test("handles emoji and special characters in event details", function (assert) {
    const title = "Test Event ????";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = {
      location: "Caf? ?",
      details: "Testing ?mojis and sp?cial ?haracters",
    };

    const icsData = generateIcsData(title, dates, options);

    assert.true(icsData.includes("??"), "preserves emoji in title");
    assert.true(icsData.includes("?"), "preserves emoji in location");
    assert.true(icsData.includes("?mojis"), "preserves accented characters");
  });

  test("generates valid base64url encoding", function (assert) {
    const title = "Test Event";
    const dates = [
      {
        startsAt: "2025-12-01T12:00:00Z",
        endsAt: "2025-12-01T13:00:00Z",
      },
    ];
    const options = { location: "Test+Location/With=Special" };

    const icsData = generateIcsData(title, dates, options);
    const base64url = bbcodeAttributeEncode(icsData);

    assert.false(
      base64url.includes("+"),
      "base64url encoding replaces + with -"
    );
    assert.false(
      base64url.includes("/"),
      "base64url encoding replaces / with _"
    );
    assert.false(
      base64url.includes("="),
      "base64url encoding replaces = with ~"
    );
    assert.true(base64url.length > 0, "produces non-empty output");

    const decoded = bbcodeAttributeDecode(base64url);
    assert.strictEqual(
      decoded,
      icsData,
      "can decode back to original ICS data"
    );
  });
});
