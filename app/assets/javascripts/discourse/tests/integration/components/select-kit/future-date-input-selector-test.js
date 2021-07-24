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
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";

discourseModule(
  "Integration | Component | select-kit/future-date-input-selector",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    hooks.afterEach(function () {
      if (this.clock) {
        this.clock.restore();
      }
    });

    componentTest("rendering and expanding", {
      template: hbs`
        {{future-date-input-selector
          options=(hash
            none="topic.auto_update_input.none"
          )
        }}
      `,

      async test(assert) {
        assert.ok(
          exists("div.future-date-input-selector"),
          "Selector is rendered"
        );

        assert.ok(
          query("span").innerText === I18n.t("topic.auto_update_input.none"),
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
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const expected = [
          I18n.t("topic.auto_update_input.later_today"),
          I18n.t("topic.auto_update_input.tomorrow"),
          I18n.t("topic.auto_update_input.next_week"),
          I18n.t("topic.auto_update_input.two_weeks"),
          I18n.t("topic.auto_update_input.next_month"),
          I18n.t("topic.auto_update_input.two_months"),
          I18n.t("topic.auto_update_input.three_months"),
          I18n.t("topic.auto_update_input.four_months"),
          I18n.t("topic.auto_update_input.six_months"),
        ];
        assert.deepEqual(options, expected);
      },
    });

    componentTest("doesn't show 'Next Week' on Sundays", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-06-13T08:00:00", timezone, true); // Sunday
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const nextWeek = I18n.t("topic.auto_update_input.next_week");
        assert.not(options.includes(nextWeek));
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
        const customDateAndTime = I18n.t(
          "topic.auto_update_input.pick_date_and_time"
        );

        assert.ok(options.includes(customDateAndTime));
      },
    });

    componentTest("shows 'This Weekend' if it's enabled", {
      template: hbs`
        {{future-date-input-selector
          includeWeekend=true
        }}
      `,

      beforeEach() {
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-06-07T08:00:00", timezone, true); // Monday
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const thisWeekend = I18n.t("topic.auto_update_input.this_weekend");

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
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-04-23 18:00:00", timezone, true); // Friday
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const thisWeekend = I18n.t("topic.auto_update_input.this_weekend");

        assert.not(options.includes(thisWeekend));
      },
    });

    componentTest(
      "shows 'Later This Week' instead of 'Later Today' at the end of the day",
      {
        template: hbs`{{future-date-input-selector}}`,

        beforeEach() {
          const timezone = moment.tz.guess();
          this.clock = fakeTime("2100-04-19 18:00:00", timezone, true); // Monday evening
        },

        async test(assert) {
          await this.subject.expand();

          const options = getOptions();
          const laterToday = I18n.t("topic.auto_update_input.later_today");
          const laterThisWeek = I18n.t(
            "topic.auto_update_input.later_this_week"
          );

          assert.not(options.includes(laterToday));
          assert.ok(options.includes(laterThisWeek));
        },
      }
    );

    componentTest("doesn't show 'Later This Week' on Tuesdays", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-04-22 18:00:00", timezone, true); // Tuesday evening
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const laterThisWeek = I18n.t("topic.auto_update_input.later_this_week");
        assert.not(options.includes(laterThisWeek));
      },
    });

    componentTest("doesn't show 'Later This Week' on Sundays", {
      /* We need this test to avoid regressions.
      We tend to write such conditions and think that
      they mean the beginning of business week
      (Monday, Tuesday and Wednesday in this specific case):

       if (date.day < 3) {
           ...
       }

      In fact, Sunday will pass this check too, because
      in moment.js 0 stands for Sunday. */

      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-04-25 18:00:00", timezone, true); // Sunday evening
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const laterThisWeek = I18n.t("topic.auto_update_input.later_this_week");
        assert.not(options.includes(laterThisWeek));
      },
    });

    componentTest("doesn't show 'Next Month' on the last day of the month", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const timezone = moment.tz.guess();
        this.clock = fakeTime("2100-04-30 18:00:00", timezone, true); // The last day of April
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const nextMonth = I18n.t("topic.auto_update_input.next_month");

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
