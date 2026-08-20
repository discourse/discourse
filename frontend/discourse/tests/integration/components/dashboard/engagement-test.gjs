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

  test("shows every KPI with its formatted value", async function (assert) {
    await render(
      <template>
        <DashboardEngagement
          @engagement={{engagement}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

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

  test("shows new activity as an increase when the prior period has no activity", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        {
          type: "new_signups",
          value: 10,
          previous_value: null,
          percent_change: null,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "New signups have increased in the selected period New signups are up."
      );
  });

  test("shows the no-data message when no metric is measurable", async function (assert) {
    const scenarioEngagement = {
      kpis: [],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Not enough activity yet to summarise engagement. Pick a longer date range or come back once your community has more activity."
      );
  });

  test("shows a decline when a negative half-step rounds to -0.1%", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        {
          type: "dau_mau",
          value: 1999,
          previous_value: 2000,
          percent_change: -0.05,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Engagement has declined in the selected period Stickiness is down. Take a look at the activity by category to see which areas of your community may need your attention."
      );
  });

  test("recommends investigating disengaged members when daily engagement has the largest displayed decline", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        {
          type: "dau_mau",
          value: 99.4,
          previous_value: 100,
          percent_change: -0.6,
        },
        {
          type: "daily_engaged_users",
          value: 98.6,
          previous_value: 100,
          percent_change: -1.4,
        },
        {
          type: "new_signups",
          value: 100,
          previous_value: 100,
          percent_change: 0,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro h3")
      .hasText("Some declines in engagement in the selected period");
    assert
      .dom(".db-section__subintro p")
      .hasText(
        "Stickiness and daily engagement are down, but new signups are holding steady. Investigate the decline to see which members have disengaged.",
        "recommends investigating disengaged members for the largest displayed decline"
      );
  });

  test("recommends reviewing activity by category when stickiness and daily engagement have equal displayed declines", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        {
          type: "dau_mau",
          value: 89.6,
          previous_value: 100,
          percent_change: -10.4,
        },
        {
          type: "daily_engaged_users",
          value: 89.51,
          previous_value: 100,
          percent_change: -10.49,
        },
        {
          type: "new_signups",
          value: 100,
          previous_value: 100,
          percent_change: 0,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro p")
      .hasText(
        "Stickiness and daily engagement are down, but new signups are holding steady. Take a look at the activity by category to see which areas of your community may need your attention.",
        "recommends reviewing activity by category for equal displayed declines"
      );
  });

  test("summarizes measurable metrics when another metric is unavailable", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        {
          type: "dau_mau",
          value: null,
          previous_value: null,
          percent_change: null,
        },
        {
          type: "daily_engaged_users",
          value: 120,
          previous_value: 100,
          percent_change: 20,
        },
        {
          type: "new_signups",
          value: 40,
          previous_value: 40,
          percent_change: 0,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement @engagement={{scenarioEngagement}} />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Daily engagement has increased in the selected period Daily engagement is up, but new signups are flat."
      );
  });
});
