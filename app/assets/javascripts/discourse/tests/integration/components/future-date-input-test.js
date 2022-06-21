import selectKit from "discourse/tests/helpers/select-kit-helper";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { fillIn } from "@ember/test-helpers";

discourseModule("Unit | Lib | select-kit/future-date-input", function (hooks) {
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
        {{future-date-input
          options=(hash
            none="time_shortcut.select_timeframe"
          )
        }}
      `,

    async test(assert) {
      assert.ok(exists(".future-date-input-selector"), "Selector is rendered");

      assert.ok(
        this.subject.header().label() ===
          I18n.t("time_shortcut.select_timeframe"),
        "Default text is rendered"
      );

      await this.subject.expand();

      assert.ok(
        exists(".select-kit-collection"),
        "List of options is rendered"
      );
    },
  });

  componentTest("renders default options", {
    template: hbs`{{future-date-input}}`,

    beforeEach() {
      const monday = "2100-12-13T08:00:00";
      this.clock = fakeTime(monday, this.currentUser.timezone, true);
    },

    async test(assert) {
      await this.subject.expand();
      const options = getOptions();
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

      assert.deepEqual(options, expected);
    },
  });

  componentTest("shows 'Custom date and time' by default", {
    template: hbs`{{future-date-input}}`,

    async test(assert) {
      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = I18n.t("time_shortcut.custom");

      assert.ok(options.includes(customDateAndTime));
    },
  });

  componentTest("doesn't show 'Custom date and time' if disabled", {
    template: hbs`
        {{future-date-input
          includeDateTime=false
        }}
      `,

    async test(assert) {
      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = I18n.t("time_shortcut.custom");

      assert.notOk(options.includes(customDateAndTime));
    },
  });

  componentTest("shows the now option if enabled", {
    template: hbs`
        {{future-date-input
          includeNow=true
        }}
      `,

    async test(assert) {
      await this.subject.expand();
      const options = getOptions();
      const now = I18n.t("time_shortcut.now");

      assert.ok(options.includes(now));
    },
  });

  componentTest("changing date/time updates the input correctly", {
    template: hbs`{{future-date-input input=input onChangeInput=(action (mut input))}}`,

    beforeEach() {
      this.set("input", moment("2032-01-01 11:10"));
    },

    async test(assert) {
      await fillIn(".time-input", "11:15");

      assert.ok(this.input.includes("2032-01-01"));
      assert.ok(this.input.includes("11:15"));

      await fillIn(".date-picker", "2033-01-01 ");

      assert.ok(this.input.includes("2033-01-01"));
      assert.ok(this.input.includes("11:15"));
    },
  });

  function getOptions() {
    return Array.from(
      queryAll(`.select-kit-collection .select-kit-row`).map(
        (_, span) => span.dataset.name
      )
    );
  }
});
