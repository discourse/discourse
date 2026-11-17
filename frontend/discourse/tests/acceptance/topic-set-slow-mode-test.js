import { click, findAll, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { FORMAT, timeShortcuts } from "discourse/lib/time-shortcut";
import dSelect from "discourse/tests/helpers/d-select-helper";
import {
  acceptance,
  fakeTime,
  loggedInUser,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Topic - Set Slow Mode", function (needs) {
  let clock = null;

  needs.user();
  needs.pretender((server, helper) => {
    server.post("/t/280/timer", () =>
      helper.response({
        success: "OK",
        execute_at: new Date(
          new Date().getTime() + 1 * 60 * 60 * 1000
        ).toISOString(),
        duration_minutes: 1440,
        based_on_last_post: false,
        closed: false,
        category_id: null,
      })
    );
  });

  needs.hooks.beforeEach(() => {
    const timezone = loggedInUser().user_option.timezone;
    clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("shows correct timeframe options", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");

    await click(".future-date-input-selector-header");

    const options = findAll(`ul.select-kit-collection li span.name`).map((x) =>
      x.innerText.trim()
    );

    const expected = [
      i18n("time_shortcut.later_today"),
      i18n("time_shortcut.tomorrow"),
      i18n("time_shortcut.two_days"),
      i18n("time_shortcut.next_week"),
      i18n("time_shortcut.two_weeks"),
      i18n("time_shortcut.next_month"),
      i18n("time_shortcut.two_months"),
      i18n("time_shortcut.custom"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});

acceptance("Topic - Set Slow Mode - new select controls", function (needs) {
  let clock = null;
  let savedSlowMode = null;

  needs.user();
  needs.settings({ enable_new_select_controls: true });
  needs.pretender((server, helper) => {
    server.put("/t/280/slow_mode", (request) => {
      savedSlowMode = helper.parsePostData(request.requestBody);
      return helper.response({ success: "OK" });
    });
  });

  needs.hooks.beforeEach(() => {
    savedSlowMode = null;
    const timezone = loggedInUser().user_option.timezone;
    clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("enables slow mode until the picked timeframe", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-slow-mode button");

    await selectKit(".slow-mode-type").expand();
    await selectKit(".slow-mode-type").selectRowByValue("600");
    await dSelect(".enabled-until .d-select").select("tomorrow");
    await click(".d-modal__footer .btn-primary");

    const tomorrow = timeShortcuts(loggedInUser().user_option.timezone)
      .tomorrow()
      .time.locale("en")
      .format(FORMAT);
    assert.strictEqual(savedSlowMode.seconds, "600");
    assert.strictEqual(
      savedSlowMode.enabled_until.slice(0, 16),
      tomorrow.slice(0, 16)
    );
  });
});
