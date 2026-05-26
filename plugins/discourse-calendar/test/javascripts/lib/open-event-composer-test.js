import { module, test } from "qunit";
import openEventComposer from "discourse/plugins/discourse-calendar/discourse/lib/open-event-composer";

function parseBbcode(body) {
  const match = body.match(/\[event (.*?)\]\n\[\/event\]\n$/);
  if (!match) {
    return null;
  }

  const params = {};
  for (const pair of match[1].matchAll(/(\w+)="([^"]*)"/g)) {
    params[pair[1]] = pair[2];
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
    assert.strictEqual(params.timezone, "America/New_York");
    assert.strictEqual(params.status, "public");
    assert.strictEqual(params.allDay, undefined, "does not emit allDay flag");
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
    assert.strictEqual(params.timezone, "Europe/Berlin");
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
