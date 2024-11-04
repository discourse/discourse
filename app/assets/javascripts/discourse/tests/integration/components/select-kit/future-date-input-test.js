import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  exists,
  fakeTime,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

function getOptions() {
  return Array.from(
    queryAll(`.select-kit-collection .select-kit-row`).map(
      (_, span) => span.dataset.name
    )
  );
}

module(
  "Integration | Component | select-kit/future-date-input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    hooks.afterEach(function () {
      this.clock?.restore();
    });

    test("rendering and expanding", async function (assert) {
      await render(hbs`
        <FutureDateInput
          @options={{hash
            none="time_shortcut.select_timeframe"
          }}
        />
      `);

      assert.ok(exists(".future-date-input-selector"), "Selector is rendered");

      assert.strictEqual(
        this.subject.header().label(),
        I18n.t("time_shortcut.select_timeframe"),
        "Default text is rendered"
      );

      await this.subject.expand();

      assert.ok(
        exists(".select-kit-collection"),
        "List of options is rendered"
      );
    });

    test("renders default options", async function (assert) {
      const monday = "2100-12-13T08:00:00";
      this.clock = fakeTime(
        monday,
        this.currentUser.user_option.timezone,
        true
      );

      await render(hbs`<FutureDateInput />`);

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
    });

    test("shows 'Custom date and time' by default", async function (assert) {
      await render(hbs`<FutureDateInput />`);

      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = I18n.t("time_shortcut.custom");

      assert.ok(options.includes(customDateAndTime));
    });

    test("doesn't show 'Custom date and time' if disabled", async function (assert) {
      await render(hbs`
        <FutureDateInput
          @includeDateTime={{false}}
        />
      `);

      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = I18n.t("time_shortcut.custom");

      assert.false(options.includes(customDateAndTime));
    });

    test("shows the now option if enabled", async function (assert) {
      await render(hbs`
        <FutureDateInput
          @includeNow={{true}}
        />
      `);

      await this.subject.expand();
      const options = getOptions();
      const now = I18n.t("time_shortcut.now");

      assert.ok(options.includes(now));
    });

    test("changing date/time updates the input correctly", async function (assert) {
      this.set("input", moment("2032-01-01 11:10"));

      await render(
        hbs`<FutureDateInput @input={{this.input}} @onChangeInput={{fn (mut this.input)}} />`
      );

      await fillIn(".time-input", "11:15");

      assert.ok(this.input.includes("2032-01-01"));
      assert.ok(this.input.includes("11:15"));

      await fillIn(".date-picker", "2033-01-01 ");

      assert.ok(this.input.includes("2033-01-01"));
      assert.ok(this.input.includes("11:15"));
    });
  }
);
