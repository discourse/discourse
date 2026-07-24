import { click, fillIn, focus, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardDateRangePicker from "discourse/admin/components/dashboard/date-range-picker";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

const TODAY = "2026-05-26 12:00";

const START_DATE_INPUT = ".d-date-range-picker__input[aria-label='Start date']";
const END_DATE_INPUT = ".d-date-range-picker__input[aria-label='End date']";

function dayButton(dateString) {
  const m = moment(dateString);
  return `.d-date-range-picker__day[aria-label="${m.format("LL")}"]:not(.--muted)`;
}

function monthHeaders() {
  return [
    ...document.querySelectorAll(".d-date-range-picker__month-title"),
  ].map((el) => el.textContent.trim());
}

function activePreset() {
  return [...document.querySelectorAll(".d-date-range-picker__preset")].find(
    (el) => el.classList.contains("is-active")
  );
}

module(
  "Integration | Component | Dashboard | DateRangePicker",
  function (hooks) {
    setupRenderingTest(hooks);

    let clock;

    hooks.beforeEach(function () {
      clock = fakeTime(TODAY, null, true);
    });

    hooks.afterEach(function () {
      clock?.restore();
    });

    test("highlights the start and end days of the active range", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      assert
        .dom(dayButton(from))
        .hasClass("--start", "the start day is highlighted as the start");
      assert
        .dom(dayButton(to))
        .hasClass("--end", "the end day is highlighted as the end");
    });

    test("marks the active preset in the sidebar", async function (assert) {
      const presets = [
        { id: "last_7_days", label: "Last 7 days" },
        { id: "last_30_days", label: "Last 30 days" },
      ];

      await render(
        <template>
          <DashboardDateRangePicker
            @presets={{presets}}
            @activePreset="last_30_days"
          />
        </template>
      );

      assert.strictEqual(
        activePreset()?.textContent.trim(),
        "Last 30 days",
        "the preset matching the active range is highlighted"
      );
    });

    test("clicking a preset emits onApply with its id", async function (assert) {
      const presets = [{ id: "last_6_months", label: "Last 6 months" }];
      const applied = [];
      const onApply = (payload) => applied.push(payload);

      await render(
        <template>
          <DashboardDateRangePicker @presets={{presets}} @onApply={{onApply}} />
        </template>
      );

      await click(".d-date-range-picker__preset");

      assert.deepEqual(
        applied,
        [{ preset: "last_6_months" }],
        "the clicked preset's id is emitted, leaving the range for the parent"
      );
    });

    test("hand-picking a range: click start, click end, Apply commits", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");
      const applied = [];
      const onApply = (payload) => applied.push(payload);

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{from}}
            @to={{to}}
            @onApply={{onApply}}
          />
        </template>
      );

      assert
        .dom(".d-date-range-picker__apply")
        .isDisabled("Apply is disabled before a pending selection is made");

      await click(dayButton("2026-05-01"));

      assert
        .dom(dayButton("2026-05-01"))
        .hasClass(
          "--start",
          "first click sets the pending start with --start class"
        );
      assert
        .dom(dayButton(to))
        .doesNotHaveClass(
          "--end",
          "the previous active end is cleared from the calendar in pending state"
        );
      assert
        .dom(".d-date-range-picker__apply")
        .isDisabled(
          "Apply stays disabled while only the start endpoint is picked"
        );

      await click(dayButton("2026-05-20"));

      assert
        .dom(dayButton("2026-05-01"))
        .hasClass("--start", "start remains highlighted after second click");
      assert
        .dom(dayButton("2026-05-20"))
        .hasClass(
          "--end",
          "second click sets the pending end with --end class"
        );
      assert.dom(".d-date-range-picker__apply").isNotDisabled();

      await click(".d-date-range-picker__apply");

      assert.strictEqual(applied.length, 1, "onApply is called once");
      const payload = applied[0];
      assert.strictEqual(payload.preset, null, "no preset is emitted");
      assert.strictEqual(
        moment(payload.from).format("YYYY-MM-DD"),
        "2026-05-01",
        "from is the picked start"
      );
      assert.strictEqual(
        moment(payload.to).format("YYYY-MM-DD"),
        "2026-05-20",
        "to is the picked end"
      );
    });

    test("typing dates in YYYY/MM/DD into the inputs updates the selection", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");
      const applied = [];
      const onApply = (payload) => applied.push(payload);

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{from}}
            @to={{to}}
            @onApply={{onApply}}
          />
        </template>
      );

      await fillIn(START_DATE_INPUT, "2026/05/02");
      await fillIn(END_DATE_INPUT, "2026/05/18");

      assert
        .dom(dayButton("2026-05-02"))
        .hasClass("--start", "typed start date is reflected on the calendar");
      assert
        .dom(dayButton("2026-05-18"))
        .hasClass("--end", "typed end date is reflected on the calendar");
      assert.dom(".d-date-range-picker__apply").isNotDisabled();

      await click(".d-date-range-picker__apply");

      const payload = applied[0];
      assert.strictEqual(
        moment(payload.from).format("YYYY-MM-DD"),
        "2026-05-02"
      );
      assert.strictEqual(moment(payload.to).format("YYYY-MM-DD"), "2026-05-18");
    });

    test("an invalid typed date reverts the input to the current selection", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await fillIn(START_DATE_INPUT, "not-a-date");

      assert
        .dom(START_DATE_INPUT)
        .hasValue(
          moment(from).format("YYYY/MM/DD"),
          "the field reverts to the active start when the input is invalid"
        );
    });

    test("clicking a date earlier than the pending start re-anchors the start", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await click(dayButton("2026-05-15"));
      await click(dayButton("2026-05-05"));

      assert
        .dom(dayButton("2026-05-05"))
        .hasClass("--start", "the earlier click becomes the new start");
      assert
        .dom(dayButton("2026-05-15"))
        .doesNotHaveClass(
          "--end",
          "the previous click is no longer the end after re-anchor"
        );
      assert
        .dom(".d-date-range-picker__apply")
        .isDisabled(
          "Apply is disabled because the end is unset after re-anchor"
        );
    });

    test("clicking a day after both endpoints are picked starts a fresh pending selection", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await click(dayButton("2026-05-01"));
      await click(dayButton("2026-05-20"));
      await click(dayButton("2026-05-10"));

      assert
        .dom(dayButton("2026-05-10"))
        .hasClass("--start", "the third click becomes the new pending start");
      assert
        .dom(dayButton("2026-05-01"))
        .doesNotHaveClass(
          "--start",
          "the previous pending start is cleared on a third click"
        );
      assert
        .dom(dayButton("2026-05-20"))
        .doesNotHaveClass(
          "--end",
          "the previous pending end is cleared on a third click"
        );
      assert
        .dom(".d-date-range-picker__apply")
        .isDisabled("Apply is disabled while only a new pending start is set");
    });

    test("Apply remains disabled when the pending range equals the active range", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await click(dayButton(from));
      await click(dayButton(to));

      assert
        .dom(".d-date-range-picker__apply")
        .isDisabled(
          "Apply is disabled because the picked range matches the active range"
        );
    });

    test("Cancel discards pending selection and calls onCancel", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");
      const applied = [];
      let cancelled = 0;
      const onApply = (payload) => applied.push(payload);
      const onCancel = () => (cancelled += 1);

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{from}}
            @to={{to}}
            @onApply={{onApply}}
            @onCancel={{onCancel}}
          />
        </template>
      );

      await click(dayButton("2026-05-01"));
      await click(".d-date-range-picker__cancel");

      assert.strictEqual(cancelled, 1, "onCancel is called");
      assert.strictEqual(applied.length, 0, "no commit happens on Cancel");
    });

    test("future dates are not selectable", async function (assert) {
      const from = moment("2026-04-27");
      const to = moment("2026-05-26");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      assert.dom(dayButton("2026-05-27")).isDisabled("tomorrow is disabled");
      assert
        .dom(dayButton("2026-05-27"))
        .hasAttribute("aria-disabled", "true", "future days are aria-disabled");
    });

    test("on open it shows two consecutive months anchored on the start month", async function (assert) {
      const from = moment("2026-01-15");
      const to = moment("2026-04-20");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      assert.deepEqual(
        monthHeaders(),
        ["January 2026", "February 2026"],
        "the start month and the following month are shown, not a start/end split"
      );
    });

    test("focusing the end input brings the end month into the right panel", async function (assert) {
      const from = moment("2026-01-15");
      const to = moment("2026-04-20");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await focus(END_DATE_INPUT);

      assert.deepEqual(
        monthHeaders(),
        ["March 2026", "April 2026"],
        "the end month sits in the right panel with the preceding month on the left"
      );
    });

    test("focusing the start input brings the start month into the left panel", async function (assert) {
      const from = moment("2026-01-15");
      const to = moment("2026-04-20");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await focus(END_DATE_INPUT);
      await focus(START_DATE_INPUT);

      assert.deepEqual(
        monthHeaders(),
        ["January 2026", "February 2026"],
        "the start month returns to the left panel when the start input is focused"
      );
    });

    test("the month navigation arrows still move the view", async function (assert) {
      const from = moment("2026-01-15");
      const to = moment("2026-04-20");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      const navButtons = document.querySelectorAll(".d-date-range-picker__nav");
      await click(navButtons[navButtons.length - 1]);

      assert.deepEqual(
        monthHeaders(),
        ["February 2026", "March 2026"],
        "the next arrow advances the visible window past the start anchor"
      );
    });

    test("focusing the end input on a same-month range keeps the end month in the right panel", async function (assert) {
      const from = moment("2026-03-10");
      const to = moment("2026-03-25");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      await focus(END_DATE_INPUT);

      assert.deepEqual(
        monthHeaders(),
        ["February 2026", "March 2026"],
        "the end month stays in the right panel even when both endpoints share a month"
      );
    });

    test("on mobile the single panel anchors on the start month and follows the focused input", async function (assert) {
      forceMobile();

      const from = moment("2026-01-15");
      const to = moment("2026-04-20");

      await render(
        <template>
          <DashboardDateRangePicker @from={{from}} @to={{to}} />
        </template>
      );

      assert.deepEqual(
        monthHeaders(),
        ["January 2026"],
        "a single month, the start month, is shown on open"
      );

      await focus(END_DATE_INPUT);

      assert.deepEqual(
        monthHeaders(),
        ["April 2026"],
        "focusing the end input shows the end month itself in the single panel"
      );
    });
  }
);
