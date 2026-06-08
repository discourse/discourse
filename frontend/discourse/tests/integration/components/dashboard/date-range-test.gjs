import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | DateRange", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a single trigger that opens the picker", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_30_days" /></template>
    );

    assert
      .dom(".db-date-range__trigger")
      .exists("a single trigger is rendered");
    assert
      .dom(".db-segmented-control")
      .doesNotExist("no segmented control is rendered");
  });

  test("trigger label is the preset name when a preset is active", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_30_days" /></template>
    );

    assert
      .dom(".db-date-range__trigger .d-button-label")
      .hasText("Last 30 days");
  });

  test("trigger label names a six-month preset rather than showing its dates", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_6_months" /></template>
    );

    assert
      .dom(".db-date-range__trigger .d-button-label")
      .hasText("Last 6 months");
  });

  test("trigger label is the literal formatted range for hand-picked custom periods", async function (assert) {
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

    assert.dom(".db-date-range__trigger .d-button-label").includesText("Mar 1");
    assert
      .dom(".db-date-range__trigger .d-button-label")
      .includesText("Apr 28");
  });

  test("trigger label falls back to default when in custom mode with missing dates", async function (assert) {
    await render(<template><DashboardDateRange @period="custom" /></template>);

    assert
      .dom(".db-date-range__trigger .d-button-label")
      .hasText("Last 30 days");
  });

  test("trigger label reacts to @period changes", async function (assert) {
    class State {
      @tracked period = "last_30_days";
    }
    const state = new State();

    await render(
      <template><DashboardDateRange @period={{state.period}} /></template>
    );

    assert
      .dom(".db-date-range__trigger .d-button-label")
      .hasText("Last 30 days");

    state.period = "last_7_days";
    await settled();

    assert
      .dom(".db-date-range__trigger .d-button-label")
      .hasText("Last 7 days");
  });
});
