import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Dashboard | EngagementHeadline behavior",
  function (hooks) {
    setupRenderingTest(hooks);

    test("treats no prior activity as a zero baseline", async function (assert) {
      const engagement = {
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
            @engagement={{engagement}}
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
      const engagement = {
        kpis: [
          {
            type: "dau_mau",
            value: null,
            previous_value: null,
            percent_change: null,
          },
          {
            type: "daily_engaged_users",
            value: null,
            previous_value: null,
            percent_change: null,
          },
          {
            type: "new_signups",
            value: null,
            previous_value: null,
            percent_change: null,
          },
        ],
      };

      await render(
        <template>
          <DashboardEngagement
            @engagement={{engagement}}
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

    test("uses metric order to resolve rounded decline ties", async function (assert) {
      const engagement = {
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
            @engagement={{engagement}}
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
      const engagement = {
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
            @engagement={{engagement}}
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
  }
);
