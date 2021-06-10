import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  fakeTime,
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
      this.clock.restore();
    });

    componentTest("shows default options", {
      template: hbs`{{future-date-input-selector}}`,

      beforeEach() {
        const monday = fakeTime("2100-06-07T08:00:00", "UTC", true);
        this.clock = monday;
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
        const sunday = fakeTime("2100-06-13T08:00:00", "UTC", true);
        this.clock = sunday;
      },

      async test(assert) {
        await this.subject.expand();

        const options = getOptions();
        const nextWeek = I18n.t("topic.auto_update_input.next_week");
        assert.not(options.includes(nextWeek));
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
