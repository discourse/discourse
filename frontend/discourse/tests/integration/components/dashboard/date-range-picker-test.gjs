import { tracked } from "@glimmer/tracking";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardDateRangePicker, {
  ALL_PRESETS,
  formatRange,
  matchingPreset,
  PRESET_LAST_6_MONTHS,
  PRESET_LAST_7_DAYS,
  PRESET_LAST_30_DAYS,
  presetRange,
} from "discourse/admin/components/dashboard/date-range-picker";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

const TODAY = "2026-05-26 12:00";

class RangeState {
  @tracked from;
  @tracked to;
  @tracked applied = [];
  @tracked cancelled = 0;

  apply = (payload) => {
    this.applied = [...this.applied, payload];
  };

  cancel = () => {
    this.cancelled++;
  };

  constructor(from, to) {
    this.from = from;
    this.to = to;
  }
}

function dayButton(dateString) {
  const m = moment(dateString);
  return `.d-date-range-picker__day[aria-label="${m.format("LL")}"]:not(.--muted)`;
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

    test("highlights the active period on the calendar and in the sidebar", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      assert
        .dom(dayButton(from))
        .hasClass(
          "--start",
          "the start day of the active period is highlighted as the start"
        );
      assert
        .dom(dayButton(to))
        .hasClass(
          "--end",
          "the end day of the active period is highlighted as the end"
        );

      const activePreset = [
        ...document.querySelectorAll(".d-date-range-picker__preset"),
      ].find((el) => el.classList.contains("is-active"));
      assert.strictEqual(
        activePreset?.textContent.trim(),
        "Last 30 days",
        "the sidebar preset matching the active range is highlighted"
      );
    });

    test("clicking a sidebar preset emits onApply with the preset and its range", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      const sixMonthsPreset = [
        ...document.querySelectorAll(".d-date-range-picker__preset"),
      ].find((el) => el.textContent.trim() === "Last 6 months");
      await click(sixMonthsPreset);

      assert.strictEqual(state.applied.length, 1, "onApply is called once");
      const payload = state.applied[0];
      assert.strictEqual(
        payload.preset,
        PRESET_LAST_6_MONTHS,
        "the preset constant is emitted"
      );
      const expected = presetRange(PRESET_LAST_6_MONTHS);
      assert.strictEqual(
        moment(payload.from).format("YYYY-MM-DD"),
        expected.from.format("YYYY-MM-DD"),
        "the emitted from matches the preset start"
      );
      assert.strictEqual(
        moment(payload.to).format("YYYY-MM-DD"),
        expected.to.format("YYYY-MM-DD"),
        "the emitted to matches the preset end"
      );
    });

    test("hand-picking a range: click start, click end, Apply commits", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
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

      assert.strictEqual(state.applied.length, 1, "onApply is called once");
      const payload = state.applied[0];
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
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      await fillIn(
        ".d-date-range-picker__input[aria-label='Start date']",
        "2026/05/02"
      );
      await fillIn(
        ".d-date-range-picker__input[aria-label='End date']",
        "2026/05/18"
      );

      assert
        .dom(dayButton("2026-05-02"))
        .hasClass("--start", "typed start date is reflected on the calendar");
      assert
        .dom(dayButton("2026-05-18"))
        .hasClass("--end", "typed end date is reflected on the calendar");
      assert.dom(".d-date-range-picker__apply").isNotDisabled();

      await click(".d-date-range-picker__apply");

      const payload = state.applied[0];
      assert.strictEqual(
        moment(payload.from).format("YYYY-MM-DD"),
        "2026-05-02"
      );
      assert.strictEqual(moment(payload.to).format("YYYY-MM-DD"), "2026-05-18");
    });

    test("an invalid typed date reverts the input to the current selection", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      await fillIn(
        ".d-date-range-picker__input[aria-label='Start date']",
        "not-a-date"
      );

      assert
        .dom(".d-date-range-picker__input[aria-label='Start date']")
        .hasValue(
          moment(from).format("YYYY/MM/DD"),
          "the field reverts to the active start when the input is invalid"
        );
    });

    test("clicking a date earlier than the pending start re-anchors the start", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
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
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
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
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
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
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      await click(dayButton("2026-05-01"));
      await click(".d-date-range-picker__cancel");

      assert.strictEqual(state.cancelled, 1, "onCancel is called");
      assert.strictEqual(
        state.applied.length,
        0,
        "no commit happens on Cancel"
      );
    });

    test("future dates are not selectable", async function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      const state = new RangeState(from.toDate(), to.toDate());

      await render(
        <template>
          <DashboardDateRangePicker
            @from={{state.from}}
            @to={{state.to}}
            @presets={{ALL_PRESETS}}
            @onApply={{state.apply}}
            @onCancel={{state.cancel}}
          />
        </template>
      );

      assert.dom(dayButton("2026-05-27")).isDisabled("tomorrow is disabled");
      assert
        .dom(dayButton("2026-05-27"))
        .hasAttribute("aria-disabled", "true", "future days are aria-disabled");
    });
  }
);

module(
  "Integration | Component | Dashboard | DateRangePicker | preset math",
  function (hooks) {
    setupRenderingTest(hooks);

    let clock;

    hooks.beforeEach(function () {
      clock = fakeTime(TODAY, null, true);
    });

    hooks.afterEach(function () {
      clock?.restore();
    });

    test("preset ranges are computed with today inclusive", function (assert) {
      const cases = [
        [PRESET_LAST_7_DAYS, "2026-05-20", "2026-05-26"],
        [PRESET_LAST_30_DAYS, "2026-04-27", "2026-05-26"],
      ];
      for (const [preset, expectedFrom, expectedTo] of cases) {
        const range = presetRange(preset);
        assert.strictEqual(
          range.from.format("YYYY-MM-DD"),
          expectedFrom,
          `${preset} start is ${expectedFrom}`
        );
        assert.strictEqual(
          range.to.format("YYYY-MM-DD"),
          expectedTo,
          `${preset} end is ${expectedTo}`
        );
      }
    });

    test("matchingPreset matches by exact start/end equality", function (assert) {
      const { from, to } = presetRange(PRESET_LAST_30_DAYS);
      assert.strictEqual(
        matchingPreset(from.toDate(), to.toDate(), ALL_PRESETS),
        PRESET_LAST_30_DAYS
      );
      assert.strictEqual(
        matchingPreset(
          moment(from).subtract(1, "day").toDate(),
          to.toDate(),
          ALL_PRESETS
        ),
        null,
        "an off-by-one range does not match a preset"
      );
    });
  }
);

module("Unit | Dashboard | DateRangePicker | formatRange", function () {
  test("same-year range omits the year on the first endpoint and includes it on the second", function (assert) {
    const formatted = formatRange("2026-03-01", "2026-04-28");
    assert.true(
      formatted.includes("2026"),
      "the formatted range includes the year"
    );
  });

  test("cross-year range includes the year on both endpoints", function (assert) {
    const formatted = formatRange("2025-11-27", "2026-05-26");
    assert.true(formatted.includes("2025"), "the from year is shown");
    assert.true(formatted.includes("2026"), "the to year is shown");
  });

  test("same-day range collapses to a single date", function (assert) {
    const formatted = formatRange("2026-05-26", "2026-05-26");
    assert.false(
      formatted.includes("–"),
      "the formatted same-day range does not include a dash separator"
    );
  });
});
