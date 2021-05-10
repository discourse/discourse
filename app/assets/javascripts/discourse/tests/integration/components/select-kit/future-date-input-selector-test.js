import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  fakeTime,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";

discourseModule(
  "Integration | Component | select-kit/future-date-input-selector",
  function (hooks) {
    let clock = null;
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    hooks.afterEach(function () {
      if (clock) {
        clock.restore();
      }
    });

    componentTest("rendering and expanding", {
      template: hbs`
        {{future-date-input-selector
          options=(hash
            none="time_shortcut.select_timeframe"
          )
        }}
      `,

      async test(assert) {
        assert.ok(
          exists("div.future-date-input-selector"),
          "Selector is rendered"
        );

        assert.ok(
          query("span").innerText === I18n.t("time_shortcut.select_timeframe"),
          "Default text is rendered"
        );

        await this.subject.expand();

        assert.equal(
          query(".future-date-input-selector-header").getAttribute(
            "aria-expanded"
          ),
          "true",
          "selector is expanded"
        );

        assert.ok(
          exists("ul.select-kit-collection"),
          "List of options is rendered"
        );
      },
    });

    componentTest("shows default options", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = this.currentUser.resolvedTimezone(this.currentUser);
        clock = fakeTime("2021-05-03T08:00:00", timezone, true); // Monday
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const expected = [
          I18n.t("time_shortcut.later_today"),
          I18n.t("time_shortcut.tomorrow"),
          I18n.t("time_shortcut.next_week"),
          I18n.t("time_shortcut.next_month"),
        ];
        assert.deepEqual(options, expected);
      },
    });

    componentTest("shows 'Custom date and time' if it's enabled", {
      template: hbs`
        {{future-date-input-selector
          includeDateTime=true
        }}
      `,

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const customDateAndTime = I18n.t("time_shortcut.custom");

        assert.ok(options.includes(customDateAndTime));
      },
    });

    componentTest("shows 'This Weekend' if it's enabled", {
      template: hbs`
        {{future-date-input-selector
          includeWeekend=true
        }}
      `,

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const thisWeekend = I18n.t("time_shortcut.this_weekend");

        assert.ok(options.includes(thisWeekend));
      },
    });

    componentTest("doesn't show 'This Weekend' on Fridays", {
      template: hbs`
        {{future-date-input-selector
          includeWeekend=true
        }}
      `,

      beforeEach() {
        const timezone = this.currentUser.resolvedTimezone(this.currentUser);
        clock = fakeTime("2021-04-23 18:00:00", timezone, true); // Friday
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const thisWeekend = I18n.t("time_shortcut.this_weekend");

        assert.not(options.includes(thisWeekend));
      },
    });

    componentTest(
      "shows 'Later This Week' instead of 'Later Today' at the end of the day",
      {
        template: hbs`{{future-date-input-selector}}`,

        beforeEach() {
          const timezone = this.currentUser.resolvedTimezone(this.currentUser);
          clock = fakeTime("2021-04-19 18:00:00", timezone, true); // Monday evening
        },

        async test(assert) {
          await this.subject.expand();
          const options = getOptions();
          const laterToday = I18n.t("time_shortcut.later_today");
          const laterThisWeek = I18n.t("time_shortcut.later_this_week");

          assert.not(options.includes(laterToday));
          assert.ok(options.includes(laterThisWeek));
        },
      }
    );

    componentTest("doesn't show 'Later This Week' on Tuesdays", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = this.currentUser.resolvedTimezone(this.currentUser);
        clock = fakeTime("2021-04-22 18:00:00", timezone, true); // Tuesday evening
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const laterThisWeek = I18n.t("time_shortcut.later_this_week");
        assert.not(options.includes(laterThisWeek));
      },
    });

    componentTest("doesn't show 'Next Week' on Sundays", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = this.currentUser.resolvedTimezone(this.currentUser);
        clock = fakeTime("2021-05-02T08:00:00", timezone, true); // Sunday
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const nextWeek = I18n.t("time_shortcut.next_week");
        assert.not(options.includes(nextWeek));
      },
    });

    componentTest("doesn't show 'Next Month' on the last day of the month", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = this.currentUser.resolvedTimezone(this.currentUser);
        clock = fakeTime("2021-04-30 18:00:00", timezone, true); // The last day of April
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const nextMonth = I18n.t("time_shortcut.next_month");

        assert.not(options.includes(nextMonth));
      },
    });

    function getOptions() {
      return Array.from(
        queryAll(`ul.select-kit-collection li span.name`).map((_, span) =>
          span.innerText.trim()
        )
      );
    }
  }
);
