import {
  acceptance,
  fakeTime,
  loggedInUser,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Admin - Silence User", function (needs) {
  let clock = null;
  needs.user();

  needs.hooks.beforeEach(() => {
    const timezone = loggedInUser().timezone;
    clock = fakeTime("2100-05-03T08:00:00", timezone, true); // Monday morning
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("shows correct timeframe options", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(".silence-user");
    await click(".future-date-input-selector-header");

    const options = Array.from(
      queryAll(`ul.select-kit-collection li span.name`).map((_, x) =>
        x.innerText.trim()
      )
    );

    const expected = [
      I18n.t("time_shortcut.later_today"),
      I18n.t("time_shortcut.tomorrow"),
      I18n.t("time_shortcut.later_this_week"),
      I18n.t("time_shortcut.start_of_next_business_week_alt"),
      I18n.t("time_shortcut.two_weeks"),
      I18n.t("time_shortcut.next_month"),
      I18n.t("time_shortcut.two_months"),
      I18n.t("time_shortcut.three_months"),
      I18n.t("time_shortcut.four_months"),
      I18n.t("time_shortcut.six_months"),
      I18n.t("time_shortcut.one_year"),
      I18n.t("time_shortcut.forever"),
      I18n.t("time_shortcut.custom"),
    ];

    assert.deepEqual(options, expected, "options are correct");
  });
});
