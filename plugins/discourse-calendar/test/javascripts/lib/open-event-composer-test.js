import { module, test } from "qunit";
import openEventComposer from "discourse/plugins/discourse-calendar/discourse/lib/open-event-composer";

function parseBbcode(body) {
  const match = body.match(/\[event (.*?)\]\n\[\/event\]\n$/);
  if (!match) {
    return null;
  }

  const params = {};
  // captures both quoted (key="value") and bare (key=value) attributes, the
  // latter being how the allDay flag is emitted.
  for (const pair of match[1].matchAll(/(\w+)="([^"]*)"|(\w+)=(\S+)/g)) {
    const key = pair[1] ?? pair[3];
    const value = pair[2] ?? pair[4];
    params[key] = value;
  }
  return params;
}

module("Unit | Lib | open-event-composer", function (hooks) {
  hooks.beforeEach(function () {
    this.calls = [];
    this.composer = {
      openNewTopic: async (opts) => {
        this.calls.push(opts);
      },
    };
  });

  test("all-day click defaults to 9:00 when the setting is unset", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "America/New_York" } },
      siteSettings: { all_day_event_start_time: "" },
      info: { dateStr: "2026-05-22", allDay: true },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(params.start, "2026-05-22 09:00");
    assert.strictEqual(
      params.end,
      "2026-05-22 10:00",
      "defaults to a 1h event"
    );
    assert.strictEqual(params.timezone, "America/New_York");
    assert.strictEqual(params.status, "public");
    assert.strictEqual(params.allDay, "true", "emits the allDay flag");
  });

  test("all-day click honors the all_day_event_start_time setting", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "America/New_York" } },
      siteSettings: { all_day_event_start_time: "08:30" },
      info: { dateStr: "2026-05-22", allDay: true },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(params.start, "2026-05-22 08:30");
  });

  test("timegrid click preserves the clicked time", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "Europe/Berlin" } },
      info: { dateStr: "2026-05-22T14:30:00", allDay: false },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(params.start, "2026-05-22 14:30");
    assert.strictEqual(
      params.end,
      "2026-05-22 15:30",
      "defaults to a 1h event"
    );
    assert.strictEqual(params.timezone, "Europe/Berlin");
    assert.strictEqual(
      params.allDay,
      undefined,
      "does not emit the allDay flag for a timed click"
    );
  });

  test("drag selection in timegrid preserves the selected start and end times", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "Europe/Berlin" } },
      info: {
        startStr: "2026-05-22T14:00:00",
        endStr: "2026-05-22T17:30:00",
        allDay: false,
      },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(params.start, "2026-05-22 14:00");
    assert.strictEqual(
      params.end,
      "2026-05-22 17:30",
      "uses the end of the selection rather than a 1h default"
    );
    assert.strictEqual(
      params.allDay,
      undefined,
      "does not emit the allDay flag for a timed selection"
    );
  });

  test("startStr takes precedence over dateStr when both are present", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "Europe/Berlin" } },
      info: {
        dateStr: "2026-05-22T09:00:00",
        startStr: "2026-05-22T14:00:00",
        endStr: "2026-05-22T15:00:00",
        allDay: false,
      },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(
      params.start,
      "2026-05-22 14:00",
      "prefers the selection start over the clicked date"
    );
  });

  test("all-day drag selection emits the allDay flag and spans the selection", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "America/New_York" } },
      siteSettings: { all_day_event_start_time: "" },
      info: {
        startStr: "2026-05-22",
        endStr: "2026-05-25",
        allDay: true,
      },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(
      params.start,
      "2026-05-22 09:00",
      "applies the all-day start time to the selection start"
    );
    assert.strictEqual(
      params.end,
      "2026-05-25 00:00",
      "uses the exclusive end of the all-day selection"
    );
    assert.strictEqual(params.allDay, "true", "emits the allDay flag");
  });

  test("all-day drag selection honors the all_day_event_start_time setting", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "America/New_York" } },
      siteSettings: { all_day_event_start_time: "08:30" },
      info: {
        startStr: "2026-05-22",
        endStr: "2026-05-23",
        allDay: true,
      },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.strictEqual(params.start, "2026-05-22 08:30");
    assert.strictEqual(params.allDay, "true", "emits the allDay flag");
  });

  test("forwards category to composer.openNewTopic", async function (assert) {
    const category = { id: 42, canCreateTopic: true };

    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "UTC" } },
      info: { dateStr: "2026-05-22", allDay: true },
      category,
    });

    assert.strictEqual(this.calls[0].category, category);
  });

  test("passes null category through (upcoming-events case)", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: { timezone: "UTC" } },
      info: { dateStr: "2026-05-22", allDay: true },
      category: null,
    });

    assert.strictEqual(this.calls[0].category, null);
  });

  test("falls back when user has no timezone preference", async function (assert) {
    await openEventComposer({
      composer: this.composer,
      currentUser: { user_option: {} },
      info: { dateStr: "2026-05-22", allDay: true },
      category: null,
    });

    const params = parseBbcode(this.calls[0].body);
    assert.notStrictEqual(
      params.timezone,
      undefined,
      "emits some timezone (guessed or UTC)"
    );
    assert.notStrictEqual(params.timezone, "", "timezone is not empty");
  });
});
