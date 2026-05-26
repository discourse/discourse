import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardDateRange, {
  calculatePresetStartDate,
} from "discourse/admin/components/dashboard/date-range";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { withFrozenTime } from "discourse/tests/helpers/qunit-helpers";

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

  test("trigger label is the preset name when a top-tier preset is active", async function (assert) {
    await render(
      <template><DashboardDateRange @period="last_30_days" /></template>
    );

    assert.dom(".db-date-range__trigger-label").hasText("Last 30 days");
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

    assert.dom(".db-date-range__trigger-label").includesText("Mar 1");
    assert.dom(".db-date-range__trigger-label").includesText("Apr 28");
  });

  test("trigger label is the literal range for sidebar-only presets (6m / 1y)", async function (assert) {
    const today = moment().startOf("day");
    const sixMonthsAgo = today
      .clone()
      .subtract(6, "months")
      .add(1, "day")
      .toDate();
    const todayDate = today.toDate();
    const expectedStart = moment(sixMonthsAgo).format("ll");
    const expectedEnd = moment(todayDate).format("ll");

    await render(
      <template>
        <DashboardDateRange
          @period="custom"
          @startDate={{sixMonthsAgo}}
          @endDate={{todayDate}}
        />
      </template>
    );

    assert
      .dom(".db-date-range__trigger-label")
      .includesText(expectedStart, "shows the literal start date");
    assert
      .dom(".db-date-range__trigger-label")
      .includesText(expectedEnd, "shows the literal end date");
  });

  test("trigger label falls back to default when in custom mode with missing dates", async function (assert) {
    await render(<template><DashboardDateRange @period="custom" /></template>);

    assert.dom(".db-date-range__trigger-label").hasText("Last 30 days");
  });

  test("trigger label reacts to @period changes", async function (assert) {
    class State {
      @tracked period = "last_30_days";
    }
    const state = new State();

    await render(
      <template><DashboardDateRange @period={{state.period}} /></template>
    );

    assert.dom(".db-date-range__trigger-label").hasText("Last 30 days");

    state.period = "last_7_days";
    await settled();

    assert.dom(".db-date-range__trigger-label").hasText("Last 7 days");
  });

  test("preset start dates include exactly the named period through today", function (assert) {
    withFrozenTime("2026-05-14 12:00:00", "UTC", () => {
      assert.strictEqual(
        moment(calculatePresetStartDate("last_7_days")).format("YYYY-MM-DD"),
        "2026-05-08"
      );
      assert.strictEqual(
        moment(calculatePresetStartDate("last_30_days")).format("YYYY-MM-DD"),
        "2026-04-15"
      );
      assert.strictEqual(
        moment(calculatePresetStartDate("last_3_months")).format("YYYY-MM-DD"),
        "2026-02-15"
      );
    });
  });
});
