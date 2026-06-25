import { module, test } from "qunit";
import {
  attendanceTransition,
  buildEventBlock,
  buildParams,
  defaultReminderFor,
  isLivestreamUrl,
  parseEventAttrs,
  parseEventBlock,
  parseReminders,
  reconcileDefaultReminder,
  reminderToBBCode,
  removeEvent,
  replaceRaw,
  stateToEventInput,
} from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";

const SAME_DAY_CONFIG = {
  startsAt: "2024-06-15T10:00:00Z",
  endsAt: "2024-06-15T11:00:00Z",
  allDay: false,
};
const ALL_DAY_CONFIG = {
  startsAt: "2024-06-15",
  endsAt: null,
  allDay: true,
};
const SHORT_DEFAULT = {
  type: "notification",
  value: 15,
  unit: "minutes",
  period: "before",
};
const LONG_DEFAULT = {
  type: "notification",
  value: 1,
  unit: "days",
  period: "before",
};

module("Unit | Lib | raw-event-helper", function () {
  test("removeEvent", function (assert) {
    assert.strictEqual(
      removeEvent('[event start="2024-01-01"]\nDescription\n[/event]'),
      "",
      "removes event with content"
    );

    assert.strictEqual(
      removeEvent(
        'Before\n[event start="2024-01-01"]\nContent\n[/event]\nAfter'
      ),
      "Before\n\nAfter",
      "preserves surrounding text"
    );

    assert.strictEqual(
      removeEvent('[event start="2024-01-01"]\n[/event]'),
      "",
      "removes event without content"
    );
  });

  test("replaceRaw", function (assert) {
    const raw = 'Some text \n[event param1="va]lue1"]\n[/event]\n more text';
    const params = {
      param1: "newValue1",
      param2: "value2",
    };

    assert.strictEqual(
      replaceRaw(params, raw),
      'Some text \n[event param1="newValue1" param2="value2"]\n[/event]\n more text',
      "updates existing parameters and adds new ones"
    );

    assert.false(
      replaceRaw(params, "No event tag here"),
      "returns false when no event tag is found"
    );

    assert.strictEqual(
      replaceRaw({ foo: 'bar"quoted' }, '[event original="value"]\n[/event]'),
      '[event foo="barquoted"]\n[/event]',
      "escapes double quotes in parameter values"
    );

    assert.strictEqual(
      replaceRaw({}, '[event param1="value1"]\n[/event]'),
      "[event ]\n[/event]",
      "handles empty params object"
    );

    assert.strictEqual(
      replaceRaw(
        { name: "", location: "Paris" },
        '[event original="value"]\n[/event]'
      ),
      '[event location="Paris"]\n[/event]',
      "omits empty name parameter"
    );

    assert.strictEqual(
      replaceRaw(
        { name: "   ", location: "Berlin" },
        '[event original="value"]\n[/event]'
      ),
      '[event location="Berlin"]\n[/event]',
      "omits whitespace-only name parameter"
    );
  });

  test("parseEventBlock extracts attrs and description, buildEventBlock round-trips", function (assert) {
    const raw =
      'preface\n[event start="2024-06-15 10:00" name="Demo"]\nbody line\n[/event]\ntail';
    const parsed = parseEventBlock(raw);

    assert.deepEqual(parsed.attrs, { start: "2024-06-15 10:00", name: "Demo" });
    assert.strictEqual(parsed.description, "body line");
    assert.strictEqual(
      parsed.full,
      '[event start="2024-06-15 10:00" name="Demo"]\nbody line\n[/event]'
    );

    assert.strictEqual(
      buildEventBlock(parsed.attrs, parsed.description),
      parsed.full,
      "buildEventBlock round-trips parsed values"
    );
  });

  test("parseEventBlock returns null when no event tag", function (assert) {
    assert.strictEqual(parseEventBlock("no event here"), null);
    assert.strictEqual(parseEventBlock(""), null);
    assert.strictEqual(parseEventBlock(null), null);
  });

  test("parseEventBlock accepts single-quoted attr values", function (assert) {
    const parsed = parseEventBlock(
      "[event start='2222-02-22 14:22' timezone='Australia/Sydney']\n[/event]"
    );
    assert.deepEqual(parsed.attrs, {
      start: "2222-02-22 14:22",
      timezone: "Australia/Sydney",
    });
  });

  test("parseEventBlock accepts unquoted attr values", function (assert) {
    const parsed = parseEventBlock(
      "[event start=2024-06-15 status=public timezone=Europe/Paris]\n[/event]"
    );
    assert.deepEqual(parsed.attrs, {
      start: "2024-06-15",
      status: "public",
      timezone: "Europe/Paris",
    });
  });

  test("parseEventBlock normalizes dashed keys to camelCase", function (assert) {
    const parsed = parseEventBlock(
      '[event start="2024-06-15 10:00" max-attendees="5" recurrence-until="2024-07-15" show-local-time="true"]\n[/event]'
    );
    assert.deepEqual(parsed.attrs, {
      start: "2024-06-15 10:00",
      maxAttendees: "5",
      recurrenceUntil: "2024-07-15",
      showLocalTime: "true",
    });
  });

  test("parseEventBlock accepts mixed quote forms in one tag", function (assert) {
    const parsed = parseEventBlock(
      `[event start="2024-06-15 10:00" status=public timezone='Europe/Paris' max-attendees=10]\nfine\n[/event]`
    );
    assert.deepEqual(parsed.attrs, {
      start: "2024-06-15 10:00",
      status: "public",
      timezone: "Europe/Paris",
      maxAttendees: "10",
    });
    assert.strictEqual(parsed.description, "fine");
  });

  test("parseReminders converts comma-separated BBCode into reminder objects", function (assert) {
    assert.deepEqual(parseReminders(""), []);
    assert.deepEqual(parseReminders(null), []);
    assert.deepEqual(
      parseReminders("notification.15.minutes,bumpTopic.-1.hours"),
      [
        { type: "notification", value: 15, unit: "minutes", period: "before" },
        { type: "bumpTopic", value: 1, unit: "hours", period: "after" },
      ]
    );
  });

  test("defaultReminderFor", function (assert) {
    assert.deepEqual(
      defaultReminderFor({
        startsAt: "2024-06-15T10:00:00Z",
        endsAt: "2024-06-15T11:00:00Z",
        allDay: false,
      }),
      { type: "notification", value: 15, unit: "minutes", period: "before" },
      "uses 15-minute reminder for same-day timed events"
    );

    assert.deepEqual(
      defaultReminderFor({
        startsAt: "2024-06-15T10:00:00Z",
        endsAt: "2024-06-16T10:00:00Z",
        allDay: false,
      }),
      { type: "notification", value: 1, unit: "days", period: "before" },
      "uses 1-day reminder for multi-day events"
    );

    assert.deepEqual(
      defaultReminderFor({
        startsAt: "2024-06-15",
        endsAt: null,
        allDay: true,
      }),
      { type: "notification", value: 1, unit: "days", period: "before" },
      "uses 1-day reminder for all-day events"
    );
  });

  test("reconcileDefaultReminder", function (assert) {
    assert.deepEqual(
      reconcileDefaultReminder([], SAME_DAY_CONFIG, ALL_DAY_CONFIG),
      [],
      "empty reminders pass through unchanged"
    );

    const multiple = [
      SHORT_DEFAULT,
      { type: "bumpTopic", value: 1, unit: "hours", period: "before" },
    ];
    assert.strictEqual(
      reconcileDefaultReminder(multiple, SAME_DAY_CONFIG, ALL_DAY_CONFIG),
      multiple,
      "multi-reminder arrays are left alone"
    );

    const customized = [
      { type: "notification", value: 30, unit: "minutes", period: "before" },
    ];
    assert.strictEqual(
      reconcileDefaultReminder(customized, SAME_DAY_CONFIG, ALL_DAY_CONFIG),
      customized,
      "user-customized reminder is preserved"
    );

    const otherSameDay = {
      startsAt: "2024-07-20T14:00:00Z",
      endsAt: "2024-07-20T15:00:00Z",
      allDay: false,
    };
    const reminders = [{ ...SHORT_DEFAULT }];
    assert.strictEqual(
      reconcileDefaultReminder(reminders, SAME_DAY_CONFIG, otherSameDay),
      reminders,
      "no swap when both configs share the same default"
    );

    assert.deepEqual(
      reconcileDefaultReminder(
        [{ ...SHORT_DEFAULT }],
        SAME_DAY_CONFIG,
        ALL_DAY_CONFIG
      ),
      [LONG_DEFAULT],
      "swaps short default for long default when going to all-day"
    );

    assert.deepEqual(
      reconcileDefaultReminder(
        [{ ...LONG_DEFAULT }],
        ALL_DAY_CONFIG,
        SAME_DAY_CONFIG
      ),
      [SHORT_DEFAULT],
      "swaps long default for short default when going to same-day timed"
    );

    assert.deepEqual(
      reconcileDefaultReminder(
        [{ ...SHORT_DEFAULT, type: "bumpTopic" }],
        SAME_DAY_CONFIG,
        ALL_DAY_CONFIG
      ),
      [{ ...LONG_DEFAULT, type: "bumpTopic" }],
      "preserves the original type when swapping default"
    );
  });

  test("reminderToBBCode", function (assert) {
    assert.strictEqual(
      reminderToBBCode({
        type: "notification",
        value: 15,
        unit: "minutes",
        period: "before",
      }),
      "notification.15.minutes",
      "serializes a before reminder"
    );

    assert.strictEqual(
      reminderToBBCode({
        type: "bumpTopic",
        value: 30,
        unit: "minutes",
        period: "after",
      }),
      "bumpTopic.-30.minutes",
      "serializes an after reminder with negative value"
    );
  });

  test("attendanceTransition: none captures status + max and flips notifications to bumpTopic", function (assert) {
    const result = attendanceTransition({
      mode: "none",
      status: "private",
      maxAttendees: 50,
      reminders: [
        { type: "notification", value: 15, unit: "minutes", period: "before" },
      ],
      previousRsvpStatus: "public",
      previousMaxAttendees: null,
    });

    assert.strictEqual(result.status, "standalone");
    assert.strictEqual(result.maxAttendees, null);
    assert.strictEqual(result.reminders[0].type, "bumpTopic");
    assert.strictEqual(result.previousRsvpStatus, "private");
    assert.strictEqual(result.previousMaxAttendees, 50);
  });

  test("attendanceTransition: switching from none to unlimited restores prior status and flips reminders", function (assert) {
    const result = attendanceTransition({
      mode: "unlimited",
      status: "standalone",
      maxAttendees: null,
      reminders: [
        { type: "bumpTopic", value: 15, unit: "minutes", period: "before" },
      ],
      previousRsvpStatus: "private",
      previousMaxAttendees: 50,
    });

    assert.strictEqual(result.status, "private");
    assert.strictEqual(result.maxAttendees, null);
    assert.strictEqual(result.reminders[0].type, "notification");
  });

  test("attendanceTransition: upTo restores previousMaxAttendees", function (assert) {
    const result = attendanceTransition({
      mode: "upTo",
      status: "standalone",
      maxAttendees: null,
      reminders: [],
      previousRsvpStatus: "public",
      previousMaxAttendees: 25,
    });

    assert.strictEqual(result.status, "public");
    assert.strictEqual(result.maxAttendees, 25);
  });

  test("attendanceTransition: upTo with no previous yields null max", function (assert) {
    const result = attendanceTransition({
      mode: "upTo",
      status: "public",
      maxAttendees: null,
      reminders: [],
      previousRsvpStatus: "public",
      previousMaxAttendees: null,
    });

    assert.strictEqual(result.maxAttendees, null);
    assert.strictEqual(result.status, "public");
  });

  test("attendanceTransition: unlimited from upTo captures the current max", function (assert) {
    const result = attendanceTransition({
      mode: "unlimited",
      status: "public",
      maxAttendees: 25,
      reminders: [],
      previousRsvpStatus: "public",
      previousMaxAttendees: null,
    });

    assert.strictEqual(result.maxAttendees, null);
    assert.strictEqual(result.previousMaxAttendees, 25);
  });

  test("attendanceTransition: does not mutate the input reminders array", function (assert) {
    const reminders = [
      { type: "notification", value: 15, unit: "minutes", period: "before" },
    ];
    attendanceTransition({
      mode: "none",
      status: "public",
      maxAttendees: null,
      reminders,
      previousRsvpStatus: "public",
      previousMaxAttendees: null,
    });
    assert.strictEqual(reminders[0].type, "notification");
  });

  test("buildParams image handling", function (assert) {
    const startsAt = "2024-06-15T10:00:00Z";
    const siteSettings = { discourse_post_event_allowed_custom_fields: "" };

    assert.strictEqual(
      buildParams(
        startsAt,
        null,
        {
          imageUpload: {
            short_url: "upload://abc123.png",
            url: "/uploads/default/original/1X/abc123.png",
          },
        },
        siteSettings
      ).image,
      "upload://abc123.png",
      "prefers short_url when available"
    );

    assert.strictEqual(
      buildParams(
        startsAt,
        null,
        { imageUpload: { url: "/uploads/default/original/1X/abc123.png" } },
        siteSettings
      ).image,
      "/uploads/default/original/1X/abc123.png",
      "falls back to url when short_url is not set"
    );

    assert.strictEqual(
      buildParams(startsAt, null, {}, siteSettings).image,
      undefined,
      "omits image when imageUpload is not set"
    );
  });

  test("livestream round-trips through state, params and parsing", function (assert) {
    const startsAt = "2024-06-15T10:00:00Z";
    const siteSettings = { discourse_post_event_allowed_custom_fields: "" };

    assert.strictEqual(
      buildParams(startsAt, null, { livestream: true }, siteSettings)
        .livestream,
      "true",
      "buildParams emits livestream when enabled"
    );

    assert.strictEqual(
      buildParams(startsAt, null, { livestream: false }, siteSettings)
        .livestream,
      undefined,
      "buildParams omits livestream when disabled"
    );

    assert.true(
      stateToEventInput({ livestream: true }).livestream,
      "stateToEventInput carries livestream through"
    );

    assert.true(
      parseEventAttrs({ livestream: "true" }).livestream,
      "parseEventAttrs reads livestream=true"
    );

    assert.false(
      parseEventAttrs({}).livestream,
      "parseEventAttrs defaults livestream to false"
    );
  });

  test("isLivestreamUrl only accepts http(s) URLs", function (assert) {
    assert.true(isLivestreamUrl("https://example.com/live"), "accepts https");
    assert.true(isLivestreamUrl("http://example.com/live"), "accepts http");
    assert.true(isLivestreamUrl("HTTPS://EXAMPLE.COM"), "case-insensitive");

    assert.false(isLivestreamUrl("www.example.com"), "rejects schemeless www");
    assert.false(isLivestreamUrl("mailto:host@example.com"), "rejects mailto");
    assert.false(isLivestreamUrl("Room 5"), "rejects plain text");
    assert.false(isLivestreamUrl(null), "handles null");
    assert.false(isLivestreamUrl(undefined), "handles undefined");
  });
});
