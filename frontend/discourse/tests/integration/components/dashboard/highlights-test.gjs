import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardHighlights from "discourse/admin/components/dashboard/highlights";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | Highlights", function (hooks) {
  setupRenderingTest(hooks);

  const start = new Date("2026-04-01");
  const end = new Date("2026-04-30");
  const reportQuery = { start_date: "2026-04-01", end_date: "2026-04-30" };

  test("renders one KpiTile per kpi in the response", async function (assert) {
    const highlights = {
      kpis: [
        {
          type: "new_signups",
          value: 1100,
          percent_change: 12,
          report_type: "signups",
          report_query: reportQuery,
        },
        {
          type: "dau_mau",
          value: 21.6,
          percent_change: 1.9,
          report_type: "dau_by_mau",
          report_query: reportQuery,
        },
        {
          type: "new_contributors",
          value: 374,
          percent_change: 6,
          report_type: "new_contributors",
          report_query: reportQuery,
        },
      ],
    };

    await render(
      <template>
        <DashboardHighlights
          @highlights={{highlights}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-kpi").exists({ count: 3 });
    assert
      .dom('a.db-kpi[href*="/admin/reports/signups"] .db-kpi__value')
      .hasText("1,100");
    assert
      .dom('a.db-kpi[href*="/admin/reports/dau_by_mau"] .db-kpi__value')
      .hasText("21.6%");
    assert
      .dom('a.db-kpi[href*="/admin/reports/new_contributors"] .db-kpi__value')
      .hasText("374");
  });

  test("omits accepted_solutions when not in the kpis array", async function (assert) {
    const highlights = {
      kpis: [
        {
          type: "new_signups",
          value: 1100,
          percent_change: 12,
          report_type: "signups",
          report_query: reportQuery,
        },
        {
          type: "new_contributors",
          value: 374,
          percent_change: 6,
          report_type: "new_contributors",
          report_query: reportQuery,
        },
      ],
    };

    await render(
      <template>
        <DashboardHighlights
          @highlights={{highlights}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-kpi").exists({ count: 2 });
    assert
      .dom('a.db-kpi[href*="/admin/reports/accepted_solutions"]')
      .doesNotExist();
  });

  test("renders no tiles when kpis is empty", async function (assert) {
    const highlights = { kpis: [] };

    await render(
      <template>
        <DashboardHighlights
          @highlights={{highlights}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-kpi").doesNotExist();
  });

  test("does not render a description headline", async function (assert) {
    const highlights = { kpis: [] };

    await render(
      <template>
        <DashboardHighlights
          @highlights={{highlights}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-section__intro").doesNotExist();
  });

  test("renders an inline error when the fetch failed", async function (assert) {
    await render(
      <template>
        <DashboardHighlights
          @highlights={{null}}
          @fetchError={{true}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-section__error").exists();
    assert.dom(".db-kpi").doesNotExist();
  });
});
