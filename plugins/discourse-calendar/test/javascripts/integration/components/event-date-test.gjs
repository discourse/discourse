import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import EventDate from "../../discourse/components/event-date";

module("Integration | Component | EventDate", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.discourse_post_event_enabled = true;
    this.siteSettings.use_local_event_date = true;
  });

  hooks.afterEach(function () {
    this.clock?.restore();
  });

  test("uses event timezone when show_local_time is true", async function (assert) {
    moment.tz.guess = () => "Africa/Harare";
    this.clock = fakeTime("2026-02-02T12:00:00Z", "Africa/Harare", true);

    // 15:00 UTC on Feb 2 is:
    // - Feb 3, 02:00 in Sydney (UTC+11)
    // - Feb 2, 17:00 in Harare (UTC+2)
    // So the date should show Feb 3 (Sydney) not Feb 2 (Harare)
    const topic = {
      event_starts_at: "2026-02-02T15:00:00.000Z",
      event_timezone: "Australia/Sydney",
      event_show_local_time: true,
    };

    await render(<template><EventDate @topic={{topic}} /></template>);

    assert
      .dom(".event-date")
      .hasAttribute(
        "title",
        /February 3, 2026/,
        "displays Feb 3 (Sydney timezone) not Feb 2 (browser Harare timezone)"
      );
  });

  test("uses browser timezone when show_local_time is false", async function (assert) {
    moment.tz.guess = () => "Africa/Harare";
    this.clock = fakeTime("2026-02-02T12:00:00Z", "Africa/Harare", true);

    // 15:00 UTC on Feb 2 is:
    // - Feb 3, 02:00 in Sydney (UTC+11)
    // - Feb 2, 17:00 in Harare (UTC+2)
    // When show_local_time is false, should use browser timezone (Harare)
    const topic = {
      event_starts_at: "2026-02-02T15:00:00.000Z",
      event_timezone: "Australia/Sydney",
      event_show_local_time: false,
    };

    await render(<template><EventDate @topic={{topic}} /></template>);

    assert
      .dom(".event-date")
      .hasAttribute(
        "title",
        /February 2, 2026.*5:00 PM/,
        "displays Feb 2 (browser Harare timezone) not Feb 3 (event Sydney timezone)"
      );
  });

  test("falls back to browser timezone when event has no timezone", async function (assert) {
    moment.tz.guess = () => "Africa/Harare";
    this.clock = fakeTime("2026-02-02T12:00:00Z", "Africa/Harare", true);

    // 15:00 UTC on Feb 2 is Feb 2, 17:00 in Harare (UTC+2)
    const topic = {
      event_starts_at: "2026-02-02T15:00:00.000Z",
    };

    await render(<template><EventDate @topic={{topic}} /></template>);

    assert
      .dom(".event-date")
      .hasAttribute(
        "title",
        /February 2, 2026.*5:00 PM/,
        "displays date in browser timezone (Harare) when no event timezone"
      );
  });
});
