import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { fillIn, findAll, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import { FORMAT } from "discourse/select-kit/components/future-date-input-selector";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import { i18n } from "discourse-i18n";

function getOptions() {
  return findAll(`.select-kit-collection .select-kit-row`).map(
    (span) => span.dataset.name
  );
}

module(
  "Integration | Component | SelectKit | FutureDateInput",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.subject = selectKit();
    });

    hooks.afterEach(function () {
      this.clock?.restore();
    });

    test("rendering and expanding", async function (assert) {
      await render(
        <template>
          <DFutureDateInput
            @options={{hash none="time_shortcut.select_timeframe"}}
          />
        </template>
      );

      assert.dom(".future-date-input-selector").exists("selector is rendered");

      assert.strictEqual(
        this.subject.header().label(),
        i18n("time_shortcut.select_timeframe"),
        "Default text is rendered"
      );

      await this.subject.expand();

      assert
        .dom(".select-kit-collection")
        .exists("list of options is rendered");
    });

    test("renders default options", async function (assert) {
      const monday = "2100-12-13T08:00:00";
      this.clock = fakeTime(
        monday,
        this.currentUser.user_option.timezone,
        true
      );

      await render(<template><DFutureDateInput /></template>);

      await this.subject.expand();
      const options = getOptions();
      const expected = [
        i18n("time_shortcut.later_today"),
        i18n("time_shortcut.tomorrow"),
        i18n("time_shortcut.later_this_week"),
        i18n("time_shortcut.start_of_next_business_week_alt"),
        i18n("time_shortcut.two_weeks"),
        i18n("time_shortcut.next_month"),
        i18n("time_shortcut.two_months"),
        i18n("time_shortcut.three_months"),
        i18n("time_shortcut.four_months"),
        i18n("time_shortcut.six_months"),
        i18n("time_shortcut.one_year"),
        i18n("time_shortcut.forever"),
        i18n("time_shortcut.custom"),
      ];

      assert.deepEqual(options, expected);
    });

    test("shows 'Custom date and time' by default", async function (assert) {
      await render(<template><DFutureDateInput /></template>);

      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = i18n("time_shortcut.custom");

      assert.true(options.includes(customDateAndTime));
    });

    test("doesn't show 'Custom date and time' if disabled", async function (assert) {
      await render(
        <template><DFutureDateInput @includeDateTime={{false}} /></template>
      );

      await this.subject.expand();
      const options = getOptions();
      const customDateAndTime = i18n("time_shortcut.custom");

      assert.false(options.includes(customDateAndTime));
    });

    test("shows the now option if enabled", async function (assert) {
      await render(
        <template><DFutureDateInput @includeNow={{true}} /></template>
      );

      await this.subject.expand();
      const options = getOptions();
      const now = i18n("time_shortcut.now");

      assert.true(options.includes(now));
    });

    test("changing date/time updates the input correctly", async function (assert) {
      this.input = moment("2032-01-01 11:10");

      await render(
        <template>
          <DFutureDateInput
            @input={{this.input}}
            @onChangeInput={{fn (mut this.input)}}
          />
        </template>
      );

      await fillIn(".time-input", "11:15");

      assert.true(this.input.includes("2032-01-01"));
      assert.true(this.input.includes("11:15"));

      await fillIn(".date-picker", "2033-01-01 ");

      assert.true(this.input.includes("2033-01-01"));
      assert.true(this.input.includes("11:15"));
    });

    test("follows a new input", async function (assert) {
      const timezone = this.currentUser.user_option.timezone;
      this.clock = fakeTime("2100-12-13T08:00:00", timezone, true);
      const input = tracked("2100-12-20 11:10");

      await render(
        <template><DFutureDateInput @input={{input.value}} /></template>
      );

      assert.strictEqual(this.subject.header().value(), "custom");
      assert.dom(".date-picker").hasValue("2100-12-20");
      assert.dom(".time-input").hasValue("11:10");

      input.value = "2100-12-21 09:30";
      await rerender();

      assert.dom(".date-picker").hasValue("2100-12-21", "updates the date");
      assert.dom(".time-input").hasValue("09:30", "updates the time");

      input.value = timeShortcuts(timezone).tomorrow().time.format(FORMAT);
      await rerender();

      assert.strictEqual(
        this.subject.header().value(),
        "tomorrow",
        "selects the matching shortcut"
      );
      assert
        .dom(".future-date-input-date-picker")
        .doesNotExist("hides the date picker");
    });

    test("keeps the custom pickers open when the input is cleared", async function (assert) {
      const input = tracked(null);
      const onChangeInput = (value) => (input.value = value);

      await render(
        <template>
          <DFutureDateInput
            @input={{input.value}}
            @onChangeInput={{onChangeInput}}
          />
        </template>
      );

      await this.subject.expand();
      await this.subject.selectRowByValue("custom");

      assert
        .dom(".future-date-input-date-picker")
        .exists("shows the date picker");
      assert.dom(".time-input").isDisabled("disables the time input");

      await fillIn(".date-picker", "2100-12-20 ");

      assert.true(input.value.includes("2100-12-20"), "updates the input");
      assert.dom(".time-input").isNotDisabled("enables the time input");

      input.value = null;
      await rerender();

      assert.strictEqual(this.subject.header().value(), "custom");
      assert
        .dom(".future-date-input-date-picker")
        .exists("keeps the date picker");
      assert
        .dom(".future-date-input-time-picker")
        .exists("keeps the time picker");
      assert.dom(".date-picker").hasValue("2100-12-20", "keeps the date");
    });

    test("label, labelClasses and displayLabelIcon", async function (assert) {
      const label = tracked("topic.slow_mode_update.enabled_until");

      await render(
        <template>
          <DFutureDateInput
            @displayLabelIcon="far-clock"
            @label={{label.value}}
            @labelClasses="slow-mode-label"
          />
        </template>
      );

      assert
        .dom("label.slow-mode-label")
        .hasText(i18n("topic.slow_mode_update.enabled_until"));
      assert.dom("label .d-icon-far-clock").exists("renders the icon");

      label.value = "admin.user.suspend_duration";
      await rerender();

      assert
        .dom("label.slow-mode-label")
        .hasText(i18n("admin.user.suspend_duration"), "updates the label");
    });

    test("doesn't mutate customShortcuts", async function (assert) {
      const timezone = this.currentUser.user_option.timezone;
      const customShortcuts = [timeShortcuts(timezone).tomorrow()];

      await render(
        <template>
          <DFutureDateInput @customShortcuts={{customShortcuts}} />
        </template>
      );

      assert.strictEqual(customShortcuts.length, 1);
    });

    test("doesn't render relative options with noRelativeOptions", async function (assert) {
      await render(
        <template>
          <DFutureDateInput
            @input="2100-12-20 11:10"
            @noRelativeOptions={{true}}
          />
        </template>
      );

      assert.dom(".future-date-input-selector").doesNotExist();
      assert.dom(".date-picker").hasValue("2100-12-20");
      assert.dom(".time-input").hasValue("11:10");
    });
  }
);
