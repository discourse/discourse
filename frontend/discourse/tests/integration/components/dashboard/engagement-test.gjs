import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | Engagement", function (hooks) {
  setupRenderingTest(hooks);

  const start = new Date("2026-04-01");
  const end = new Date("2026-04-30");
  const reportQuery = { start_date: "2026-04-01", end_date: "2026-04-30" };

  const engagement = {
    headline: {
      key: "admin.dashboard.sections.engagement.headline.healthy_growth",
    },
    kpis: [
      {
        type: "dau_mau",
        value: 21.6,
        percent_change: 1.9,
        report_type: "dau_by_mau",
        report_query: reportQuery,
      },
      {
        type: "daily_engaged_users",
        value: 150,
        percent_change: -5,
        report_type: "daily_engaged_users",
        report_query: reportQuery,
      },
      {
        type: "new_signups",
        value: 248,
        percent_change: 9,
        report_type: "signups",
        report_query: reportQuery,
      },
    ],
  };

  test("renders the headline title, summary and one metric per kpi", async function (assert) {
    await render(
      <template>
        <DashboardEngagement
          @engagement={{engagement}}
          @period="last_30_days"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert
      .dom(".db-section__subintro h3")
      .hasText("Members are forming a habit of coming back.");
    assert.dom(".db-section__subintro p").exists();
    assert.dom(".db-section__metric").exists({ count: 3 });
    assert
      .dom(
        ".db-section__metrics .db-section__metric:nth-child(1) .db-section__metric-number"
      )
      .hasText("21.6%");
    assert
      .dom(
        ".db-section__metrics .db-section__metric:nth-child(2) .db-section__metric-number"
      )
      .hasText("150");
    assert
      .dom(
        ".db-section__metrics .db-section__metric:nth-child(3) .db-section__metric-number"
      )
      .hasText("248");
  });

  test("renders an inline error when the section fetch failed", async function (assert) {
    await render(
      <template>
        <DashboardEngagement
          @engagement={{null}}
          @fetchError={{true}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-section__error").exists();
    assert.dom(".db-section__metric").doesNotExist();
  });

  test("omits the headline block when the engagement payload is missing", async function (assert) {
    await render(
      <template>
        <DashboardEngagement
          @engagement={{null}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-section__subintro").doesNotExist();
  });
});
