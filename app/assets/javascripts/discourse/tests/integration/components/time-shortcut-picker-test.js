import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  fakeTime,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";
import { click } from "@ember/test-helpers";

discourseModule(
  "Integration | Component | time-shortcut-picker",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`{{time-shortcut-picker _itsatrap=itsatrap}}`;

    hooks.beforeEach(function () {
      const itsatrapStub = {
        bind: () => {},
        unbind: () => {},
      };

      this.set("itsatrap", itsatrapStub);
    });

    hooks.afterEach(function () {
      if (this.clock) {
        this.clock.restore();
      }
    });

    componentTest("shows default options", {
      template,

      beforeEach() {
        const tuesday = "2100-06-08T08:00:00";
        this.clock = fakeTime(tuesday, this.currentUser._timezone, true);
      },

      async test(assert) {
        const expected = [
          I18n.t("time_shortcut.later_today"),
          I18n.t("time_shortcut.tomorrow"),
          I18n.t("time_shortcut.later_this_week"),
          I18n.t("time_shortcut.this_weekend"),
          I18n.t("time_shortcut.start_of_next_business_week"),
          I18n.t("time_shortcut.next_month"),
          I18n.t("time_shortcut.custom"),
          I18n.t("time_shortcut.none"),
        ];

        const options = Array.from(
          queryAll("div.tap-tile-grid div.tap-tile-title").map((_, div) =>
            div.innerText.trim()
          )
        );

        assert.deepEqual(options, expected);
      },
    });

    componentTest("show 'Later This Week' if today is < Thursday", {
      template,

      beforeEach() {
        const monday = "2100-06-07T08:00:00";
        this.clock = fakeTime(monday, this.currentUser._timezone, true);
      },

      test(assert) {
        assert.ok(
          exists("#tap_tile_later_this_week"),
          "it has later this week"
        );
      },
    });

    componentTest("does not show 'Later This Week' if today is >= Thursday", {
      template,

      beforeEach() {
        const thursday = "2100-06-10T08:00:00";
        this.clock = fakeTime(thursday, this.currentUser._timezone, true);
      },

      test(assert) {
        assert.notOk(
          exists("#tap_tile_later_this_week"),
          "it does not have later this week"
        );
      },
    });

    componentTest("does not show 'Later Today' if 'Later Today' is tomorrow", {
      template,

      beforeEach() {
        this.clock = fakeTime(
          "2100-12-11T22:00:00", // + 3 hours is tomorrow
          this.currentUser._timezone,
          true
        );
      },

      test(assert) {
        assert.notOk(
          exists("#tap_tile_later_today"),
          "it does not have later today"
        );
      },
    });

    componentTest("shows 'Later Today' if it is before 5pm", {
      template,

      beforeEach() {
        this.clock = fakeTime(
          "2100-12-11T16:50:00",
          this.currentUser._timezone,
          true
        );
      },

      test(assert) {
        assert.ok(exists("#tap_tile_later_today"), "it does have later today");
      },
    });

    componentTest("does not show 'Later Today' if it is after 5pm", {
      template,

      beforeEach() {
        this.clock = fakeTime(
          "2100-12-11T17:00:00",
          this.currentUser._timezone,
          true
        );
      },

      test(assert) {
        assert.notOk(
          exists("#tap_tile_later_today"),
          "it does not have later today"
        );
      },
    });

    componentTest("defaults to 08:00 for custom time", {
      template,

      async test(assert) {
        await click("#tap_tile_custom");
        assert.strictEqual(query("#custom-time").value, "08:00");
      },
    });

    componentTest("shows 'Next Monday' instead of 'Monday' on Sundays", {
      template,

      beforeEach() {
        const sunday = "2100-01-24T08:00:00";
        this.clock = fakeTime(sunday, this.currentUser._timezone, true);
      },

      async test(assert) {
        assert.equal(
          query("#tap_tile_start_of_next_business_week .tap-tile-title")
            .innerText,
          "Next Monday"
        );

        assert.equal(
          query("div#tap_tile_start_of_next_business_week div.tap-tile-date")
            .innerText,
          "Feb 1, 8:00 am"
        );
      },
    });

    componentTest("shows 'Next Monday' instead of 'Monday' on Mondays", {
      template,

      beforeEach() {
        const monday = "2100-01-25T08:00:00";
        this.clock = fakeTime(monday, this.currentUser._timezone, true);
      },

      async test(assert) {
        assert.equal(
          query("#tap_tile_start_of_next_business_week .tap-tile-title")
            .innerText,
          "Next Monday"
        );

        assert.equal(
          query("div#tap_tile_start_of_next_business_week div.tap-tile-date")
            .innerText,
          "Feb 1, 8:00 am"
        );
      },
    });

    componentTest(
      "the 'Next Month' option points to the first day of the next month",
      {
        template,

        beforeEach() {
          this.clock = fakeTime(
            "2100-01-01T08:00:00",
            this.currentUser._timezone,
            true
          );
        },

        async test(assert) {
          assert.strictEqual(
            query("div#tap_tile_next_month div.tap-tile-date").innerText,
            "Feb 1, 8:00 am"
          );
        },
      }
    );
  }
);
