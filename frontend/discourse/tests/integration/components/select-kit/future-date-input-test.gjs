import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { click, fillIn, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { FORMAT, formatTime, timeShortcuts } from "discourse/lib/time-shortcut";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import { i18n } from "discourse-i18n";

function getOptions() {
  return findAll(`.select-kit-collection .select-kit-row`).map(
    (span) => span.dataset.name
  );
}

function optionNames() {
  return findAll("[role='option']").map((option) => option.dataset.name);
}

function tomorrowRowParts() {
  const row = document.querySelector(
    "[role='option'][data-value='tomorrow'] .d-select__option-content"
  );
  return [
    row.firstElementChild.getBoundingClientRect(),
    row.querySelector(".d-select__option-description").getBoundingClientRect(),
  ];
}

function accessibleName(element) {
  const labelledBy = element.getAttribute("aria-labelledby");
  if (labelledBy) {
    return labelledBy
      .split(" ")
      .map((id) => document.getElementById(id).textContent.trim())
      .join(" ");
  }
  return element.getAttribute("aria-label");
}

module(
  "Integration | Component | SelectKit | FutureDateInput",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
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
      this.set("input", moment("2032-01-01 11:10"));

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

    module("with the new select controls", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.enable_new_select_controls = true;
        this.clock = fakeTime(
          "2100-12-13T08:00:00",
          this.currentUser.user_option.timezone,
          true
        );
        this.shortcuts = timeShortcuts(this.currentUser.user_option.timezone);
      });

      test("offers the shortcuts with their dates as descriptions", async function (assert) {
        await render(<template><DFutureDateInput /></template>);
        await dSelect(".future-date-input .d-select").open();

        assert.deepEqual(optionNames(), [
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
        ]);
        assert
          .dom(
            "[role='option'][data-value='tomorrow'] .d-select__option-description"
          )
          .hasText(formatTime(this.shortcuts.tomorrow()));
        assert
          .dom(
            "[role='option'][data-value='custom'] .d-select__option-description"
          )
          .doesNotExist();
      });

      test("picking a shortcut emits its date", async function (assert) {
        const emitted = [];
        const record = (value) => emitted.push(value);

        await render(
          <template><DFutureDateInput @onChangeInput={{record}} /></template>
        );
        await dSelect(".future-date-input .d-select").select("tomorrow");

        assert.deepEqual(emitted, [
          this.shortcuts.tomorrow().time.locale("en").format(FORMAT),
        ]);
        assert
          .dom(".future-date-input .d-select")
          .hasAttribute("data-value", "tomorrow");
      });

      test("puts a row's date beside its name when it fits", async function (assert) {
        await render(<template><DFutureDateInput /></template>);
        await dSelect(".future-date-input .d-select").open();

        const [name, date] = tomorrowRowParts();
        assert.true(Math.abs(name.top - date.top) < 1, "same row");
        assert.true(date.left > name.right, "after the name");
      });

      test("puts a row's date under its name when it doesn't fit", async function (assert) {
        const narrow = document.createElement("style");
        narrow.textContent =
          "[data-identifier='future-date-input'][data-content] { width: 8em !important; }";
        document.head.append(narrow);

        try {
          await render(<template><DFutureDateInput /></template>);
          await dSelect(".future-date-input .d-select").open();

          const [name, date] = tomorrowRowParts();
          assert.true(date.top >= name.bottom - 1, "on the next line");
          assert.true(
            Math.abs(date.left - name.left) < 1,
            "aligned with the name"
          );
        } finally {
          narrow.remove();
        }
      });

      test("shows the held shortcut's date in the trigger", async function (assert) {
        await render(
          <template>
            <DFutureDateInput />
            <button class="elsewhere" type="button">Elsewhere</button>
          </template>
        );
        await dSelect(".future-date-input .d-select").select("tomorrow");
        await click(".elsewhere");

        assert
          .dom(".future-date-input .d-select")
          .includesText(i18n("time_shortcut.tomorrow"))
          .includesText(formatTime(this.shortcuts.tomorrow()));
      });

      test("right-aligns the held date in the trigger", async function (assert) {
        await render(
          <template>
            <div style="width: 30em">
              <DFutureDateInput />
            </div>
            <button class="elsewhere" type="button">Elsewhere</button>
          </template>
        );
        await dSelect(".future-date-input .d-select").select("tomorrow");
        await click(".elsewhere");

        const date = document
          .querySelector(".future-date-input__selection-date")
          .getBoundingClientRect();
        const caret = document
          .querySelector(".future-date-input .d-select__caret")
          .getBoundingClientRect();
        assert.true(
          caret.left - date.right < 16,
          `the date ends next to the caret (gap ${caret.left - date.right}px)`
        );
      });

      test("typing a date finds the shortcut that ends then", async function (assert) {
        await render(<template><DFutureDateInput /></template>);
        await dSelect(".future-date-input .d-select").search(
          formatTime(this.shortcuts.twoWeeks())
        );

        assert.deepEqual(
          findAll("[role='option']").map((option) => option.dataset.value),
          ["two_weeks"]
        );
      });

      test("date search ignores accents", async function (assert) {
        await render(<template><DFutureDateInput /></template>);
        await dSelect(".future-date-input .d-select").search(
          formatTime(this.shortcuts.twoWeeks()).replace(/e/i, "é")
        );

        assert.deepEqual(
          findAll("[role='option']").map((option) => option.dataset.value),
          ["two_weeks"]
        );
      });

      test("picking Custom shows the date and time fields and emits nothing", async function (assert) {
        const emitted = [];
        const record = (value) => emitted.push(value);

        await render(
          <template><DFutureDateInput @onChangeInput={{record}} /></template>
        );
        assert.dom(".future-date-input-date-picker").doesNotExist();

        await dSelect(".future-date-input .d-select").select("custom");

        assert.dom(".future-date-input-date-picker").exists();
        assert.dom(".future-date-input-time-picker").exists();
        assert.deepEqual(emitted, []);
      });

      test("drops Custom without date and time, and adds Now on request", async function (assert) {
        await render(
          <template>
            <DFutureDateInput @includeDateTime={{false}} @includeNow={{true}} />
          </template>
        );
        await dSelect(".future-date-input .d-select").open();

        const names = optionNames();
        assert.false(names.includes(i18n("time_shortcut.custom")));
        assert.true(names.includes(i18n("time_shortcut.now")));
      });

      test("holds the shortcut an incoming date matches, otherwise Custom", async function (assert) {
        const incoming = tracked(this.shortcuts.tomorrow().time);

        await render(
          <template><DFutureDateInput @input={{incoming.value}} /></template>
        );

        assert
          .dom(".future-date-input .d-select")
          .hasAttribute("data-value", "tomorrow");

        incoming.value = moment("2101-03-04 10:20");
        await settled();

        assert
          .dom(".future-date-input .d-select")
          .hasAttribute("data-value", "custom");
        assert
          .dom(".future-date-input-date-picker input")
          .hasValue("2101-03-04");
      });

      test("renders no select without relative options", async function (assert) {
        await render(
          <template><DFutureDateInput @noRelativeOptions={{true}} /></template>
        );

        assert.dom(".future-date-input .d-select").doesNotExist();
      });

      test("is named by its label", async function (assert) {
        await render(
          <template>
            <DFutureDateInput @label="topic.slow_mode_update.enabled_until" />
          </template>
        );

        assert.strictEqual(
          accessibleName(document.querySelector("[role='combobox']")),
          i18n("topic.slow_mode_update.enabled_until")
        );
      });

      test("takes a spoken name when it has no visible label", async function (assert) {
        await render(
          <template>
            <DFutureDateInput
              @ariaLabel={{i18n "topic.feature_topic.pin_until"}}
            />
          </template>
        );

        assert.strictEqual(
          accessibleName(document.querySelector("[role='combobox']")),
          i18n("topic.feature_topic.pin_until")
        );
      });

      test("clearing shows the placeholder and empties the date", async function (assert) {
        const emitted = [];
        const record = (value) => emitted.push(value);
        const tomorrow = this.shortcuts.tomorrow().time;

        await render(
          <template>
            <DFutureDateInput
              @clearable={{true}}
              @input={{tomorrow}}
              @onChangeInput={{record}}
            />
          </template>
        );
        await dSelect(".future-date-input .d-select").clear();

        assert
          .dom(".future-date-input .d-select")
          .hasAttribute("data-value", "");
        assert
          .dom(".future-date-input [role='combobox']")
          .hasValue("")
          .hasAttribute("placeholder", i18n("time_shortcut.select_timeframe"));
        assert.deepEqual(emitted, [null]);
      });
    });
  }
);
