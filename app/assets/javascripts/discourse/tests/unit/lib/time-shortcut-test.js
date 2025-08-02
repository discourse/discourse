import { module, test } from "qunit";
import {
  defaultTimeShortcuts,
  hideDynamicTimeShortcuts,
} from "discourse/lib/time-shortcut";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

module(
  "Unit | Lib | time-shortcut | hideDynamicTimeShortcuts",
  function (hooks) {
    hooks.afterEach(function () {
      this.clock?.restore();
    });

    test("hides 'Later Today' at the end of the day", function (assert) {
      const timezone = moment.tz.guess();
      const shortcuts = defaultTimeShortcuts(timezone);

      this.clock = fakeTime("2100-04-19 08:00:00", timezone, true); // morning
      let result = hideDynamicTimeShortcuts(shortcuts, timezone).mapBy("id");
      assert.true(
        result.includes("later_today"),
        "shows later_today in the morning"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-19 18:00:00", timezone, true); // evening
      result = hideDynamicTimeShortcuts(shortcuts, timezone).mapBy("id");
      assert.false(result.includes("doesn't show later_today in the evening"));
    });

    test("hides 'Later This Week' starting from Thursday", function (assert) {
      const timezone = moment.tz.guess();
      const shortcuts = defaultTimeShortcuts(timezone);

      this.clock = fakeTime("2100-04-21 18:00:00", timezone, true); // Wednesday
      let result = hideDynamicTimeShortcuts(shortcuts, timezone).mapBy("id");
      assert.true(
        result.includes("later_this_week"),
        "shows later_this_week on Wednesdays"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-22 18:00:00", timezone, true); // Thursday
      result = hideDynamicTimeShortcuts(shortcuts, timezone).mapBy("id");
      assert.false(
        result.includes("later_this_week"),
        "doesn't show later_this_week on Thursdays"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-23 18:00:00", timezone, true); // Friday
      result = hideDynamicTimeShortcuts(shortcuts, timezone).mapBy("id");
      assert.false(
        result.includes("later_this_week"),
        "doesn't show later_this_week on Fridays"
      );
    });

    test("hides 'This Weekend' on Fridays, Saturdays and Sundays", function (assert) {
      const siteSettings = { suggest_weekends_in_date_pickers: true };
      const timezone = moment.tz.guess();
      const shortcuts = defaultTimeShortcuts(timezone);

      this.clock = fakeTime("2100-04-22 18:00:00", timezone, true); // Thursday
      let result = hideDynamicTimeShortcuts(
        shortcuts,
        timezone,
        siteSettings
      ).mapBy("id");
      assert.true(
        result.includes("this_weekend"),
        "shows this_weekend on Thursdays"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-23 18:00:00", timezone, true); // Friday
      result = hideDynamicTimeShortcuts(
        shortcuts,
        timezone,
        siteSettings
      ).mapBy("id");
      assert.false(
        result.includes("this_weekend"),
        "doesn't show this_weekend on Fridays"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-24 18:00:00", timezone, true); // Saturday
      result = hideDynamicTimeShortcuts(
        shortcuts,
        timezone,
        siteSettings
      ).mapBy("id");
      assert.false(
        result.includes("this_weekend"),
        "doesn't show this_weekend on Saturdays"
      );

      this.clock.restore();
      this.clock = fakeTime("2100-04-25 18:00:00", timezone, true); // Sunday
      result = hideDynamicTimeShortcuts(
        shortcuts,
        timezone,
        siteSettings
      ).mapBy("id");
      assert.false(
        result.includes("this_weekend"),
        "doesn't show this_weekend on Sundays"
      );
    });

    test("hides 'This Weekend' when disabled in site settings", function (assert) {
      const siteSettings = { suggest_weekends_in_date_pickers: false };
      const timezone = moment.tz.guess();
      const shortcuts = defaultTimeShortcuts(timezone);

      this.clock = fakeTime("2100-04-19 18:00:00", timezone, true); // Monday
      let result = hideDynamicTimeShortcuts(
        shortcuts,
        timezone,
        siteSettings
      ).mapBy("id");
      assert.false(
        result.includes("this_weekend"),
        "shows this_weekend on Thursdays"
      );
    });
  }
);
