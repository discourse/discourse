import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | DateRange", function (hooks) {
  setupRenderingTest(hooks);

  test("renders all four items in the segmented control", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_30_days" /></template>
    );

    assert.dom("input[value='last_7_days']").exists("renders Last 7 days");
    assert.dom("input[value='last_30_days']").exists("renders Last 30 days");
    assert.dom("input[value='last_3_months']").exists("renders Last 3 months");
    assert.dom("input[value='custom']").exists("renders Custom");
  });

  test("checks the input matching @period", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_7_days" /></template>
    );

    assert
      .dom("input[value='last_7_days']")
      .isChecked("active preset is checked");
    assert
      .dom("input[value='last_30_days']")
      .isNotChecked("inactive preset is not checked");
  });

  test("checks the custom input when @period is 'custom'", async function (assert) {
    const start = new Date("2026-03-01");
    const end = new Date("2026-04-28");

    await render(
      <template>
        <DashboardDateRange
          @period="custom"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom("input[value='custom']").isChecked();
  });

  test("calls @setPeriod when a preset is clicked", async function (assert) {
    const calls = [];
    const setPeriod = (period) => calls.push(period);

    await render(
      <template>
        <DashboardDateRange @period="last_30_days" @setPeriod={{setPeriod}} />
      </template>
    );

    await click("input[value='last_7_days']");
    assert.deepEqual(calls, ["last_7_days"], "fires with the chosen value");
  });

  test("does not call @setPeriod when the custom item is clicked", async function (assert) {
    const calls = [];
    const setPeriod = (period) => calls.push(period);

    await render(
      <template>
        <DashboardDateRange @period="last_30_days" @setPeriod={{setPeriod}} />
      </template>
    );

    await click(".db-date-range__custom");
    assert.deepEqual(calls, [], "custom does not change preset state");
  });

  test("custom item label is 'Custom' when not in custom mode", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_30_days" /></template>
    );

    assert.dom(".db-date-range__custom").includesText("Custom");
  });

  test("custom item label shows the formatted range when in custom mode", async function (assert) {
    const start = new Date("2026-03-01");
    const end = new Date("2026-04-28");

    await render(
      <template>
        <DashboardDateRange
          @period="custom"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-date-range__custom").includesText("Mar 1");
    assert.dom(".db-date-range__custom").includesText("Apr 28");
  });

  test("custom item label falls back to 'Custom' when dates are missing", async function (assert) {
    await render(<template><DashboardDateRange @period="custom" /></template>);

    assert.dom(".db-date-range__custom").includesText("Custom");
  });

  test("checked state on custom toggles when @period changes", async function (assert) {
    class State {
      @tracked period = "last_30_days";
    }
    const state = new State();

    await render(
      <template><DashboardDateRange @period={{state.period}} /></template>
    );

    assert.dom("input[value='custom']").isNotChecked();

    state.period = "custom";
    await settled();

    assert.dom("input[value='custom']").isChecked();
  });
});
