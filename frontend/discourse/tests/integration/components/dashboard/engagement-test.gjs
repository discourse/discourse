import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import { engagementHeadlineTitleKey } from "discourse/admin/lib/engagement-headline";
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

  test("looks up a headline by scenario", function (assert) {
    assert.strictEqual(
      engagementHeadlineTitleKey("improved_declined_flat"),
      "stickiness_increased",
      "returns the semantic headline key"
    );
  });

  test("renders one metric per kpi", async function (assert) {
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

  test("renders the PM headline when all metrics improve", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        { type: "dau_mau", value: 30, previous_value: 20, percent_change: 50 },
        {
          type: "daily_engaged_users",
          value: 150,
          previous_value: 100,
          percent_change: 50,
        },
        {
          type: "new_signups",
          value: 60,
          previous_value: 40,
          percent_change: 50,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );
    assert.deepEqual(
      [
        find(".db-section__subintro h3").textContent.trim(),
        find(".db-section__subintro p").textContent.trim(),
      ],
      [
        "Engagement is up in the last 30 days",
        "Stickiness, daily engagement, and new signups have all improved, showing that more members are joining and participating in your community.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when metrics move in different directions and new signups decline most", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        { type: "dau_mau", value: 30, previous_value: 20, percent_change: 50 },
        {
          type: "daily_engaged_users",
          value: 150,
          previous_value: 100,
          percent_change: 50,
        },
        {
          type: "new_signups",
          value: 20,
          previous_value: 40,
          percent_change: -50,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );
    assert.deepEqual(
      [
        find(".db-section__subintro h3").textContent.trim(),
        find(".db-section__subintro p").textContent.trim(),
      ],
      [
        "Stickiness and daily engagement have increased in the last 30 days",
        "Stickiness and daily engagement are up, but new signups are down. Look at your site traffic data to understand how traffic patterns might be influencing your signups this period.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when all metrics stay flat", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        { type: "dau_mau", value: 20, previous_value: 20, percent_change: 0 },
        {
          type: "daily_engaged_users",
          value: 100,
          previous_value: 100,
          percent_change: 0,
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );
    assert.deepEqual(
      [
        find(".db-section__subintro h3").textContent.trim(),
        find(".db-section__subintro p").textContent.trim(),
      ],
      [
        "Engagement is steady in the last 30 days",
        "No meaningful change in stickiness, daily engagement, or new signups.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline for a custom period", async function (assert) {
    const scenarioEngagement = {
      kpis: [
        { type: "dau_mau", value: 30, previous_value: 20, percent_change: 50 },
        {
          type: "daily_engaged_users",
          value: 150,
          previous_value: 100,
          percent_change: 50,
        },
        {
          type: "new_signups",
          value: 60,
          previous_value: 40,
          percent_change: 50,
        },
      ],
    };

    await render(
      <template>
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="custom"
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );
    assert.deepEqual(
      [
        find(".db-section__subintro h3").textContent.trim(),
        find(".db-section__subintro p").textContent.trim(),
      ],
      [
        "Engagement is up in the selected period",
        "Stickiness, daily engagement, and new signups have all improved, showing that more members are joining and participating in your community.",
      ],
      "renders selected-period wording"
    );
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

  test("treats no prior activity as a zero baseline", async function (assert) {
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "New signups have increased in the last 30 days New signups are up."
      );
  });

  test("preserves the no-data headline when no metric is measurable", async function (assert) {
    const scenarioEngagement = {
      kpis: [],
    };

    await render(
      <template>
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Not enough activity yet to summarise engagement. Pick a longer date range or come back once your community has more activity."
      );
  });

  test("classifies a visible negative half-step change as a decline", async function (assert) {
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Engagement has declined in the last 30 days Stickiness is down. Take a look at the activity by category to see which areas of your community may need your attention."
      );
  });

  test("chooses the largest decline using the tile's display rounding", async function (assert) {
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro p")
      .includesText(
        "Investigate the decline to see which members have disengaged.",
        "daily engagement owns the CTA because -1% is below -0.6%"
      );
  });

  test("uses metric order to resolve rounded decline ties", async function (assert) {
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro p")
      .includesText(
        "Take a look at the activity by category",
        "stickiness owns the CTA when rounded declines tie"
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
        <DashboardEngagement
          @engagement={{scenarioEngagement}}
          @period="last_30_days"
        />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "Daily engagement has increased in the last 30 days Daily engagement is up, but new signups are flat."
      );
  });
});
