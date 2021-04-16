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
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
      this.clock = fakeTime("2021-05-03T08:00:00", "UTC", true); // Monday
    });

    hooks.afterEach(function () {
      this.clock.restore();
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

    componentTest("shows far feature options if it's enabled", {
      template: hbs`
        {{future-date-input-selector
          includeFarFuture=true
        }}
      `,

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
          I18n.t("topic.auto_update_input.one_year"),
          I18n.t("topic.auto_update_input.forever"),
        ];

        assert.deepEqual(options, expected);
      },
    });

    componentTest("shows 'Pick Date and Time' if it's enabled", {
      template: hbs`
        {{future-date-input-selector
          includeDateTime=true
        }}
      `,

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const pickDateAndTime = I18n.t(
          "topic.auto_update_input.pick_date_and_time"
        );

        assert.ok(options.includes(pickDateAndTime));
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
        this.clock = fakeTime("2021-04-23 18:00:00", "UTC", true); // Friday
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
          this.clock = fakeTime("2021-04-19 18:00:00", "UTC", true); // Monday evening
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
        this.clock = fakeTime("2021-04-22 18:00:00", "UTC", true); // Tuesday evening
      },

      async test(assert) {
        await this.subject.expand();
        const options = getOptions();
        const laterThisWeek = I18n.t("topic.auto_update_input.later_this_week");
        assert.not(options.includes(laterThisWeek));
      },
    });

    componentTest("doesn't show 'Next Week' on Sundays", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        this.clock = fakeTime("2021-05-02T08:00:00", "UTC", true); // Sunday
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const nextWeek = I18n.t("topic.auto_update_input.next_week");
        assert.not(options.includes(nextWeek));
      },
    });

    componentTest("doesn't show 'Next Month' on the last day of the month", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        this.clock = fakeTime("2021-04-30 18:00:00", "UTC", true); // The last day of April
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
