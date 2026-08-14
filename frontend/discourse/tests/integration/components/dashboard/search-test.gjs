import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSearch from "discourse/admin/components/dashboard/search";
import { searchHeadlineKeys } from "discourse/admin/lib/search-headline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const startDate = new Date("2026-04-01");
const endDate = new Date("2026-04-30");

module("Integration | Component | Dashboard | Search", function (hooks) {
  setupRenderingTest(hooks);

  test("selects the content-gaps message when searches and the no-result rate increase", function (assert) {
    assert.deepEqual(
      searchHeadlineKeys({ searches: "up", noResultRate: "up" }),
      {
        title: "searches_increased",
        summary: "searches_up_no_result_rate_up",
        cta: "content_gaps",
      },
      "selects content-gap copy for a worsening no-result rate"
    );
  });

  test("shows improving search results when searches increase and the no-result rate declines", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 120,
          previous_value: 100,
          percent_change: 20,
        },
        no_result_rate: {
          value: 8,
          previous_value: 10,
          point_change: -2,
          exceeds_threshold: false,
        },
      },
      trending: [],
      content_gaps: [],
      trending_period: "monthly",
    };

    await render(
      <template>
        <DashboardSearch
          @search={{search}}
          @period="last_30_days"
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );
    assert.deepEqual(
      [
        find(".db-section__subintro h3").textContent.trim(),
        find(".db-section__subintro p").textContent.trim(),
      ],
      [
        "Searches have increased and the no-result rate has declined in the last 30 days",
        "Members are conducting more searches in your community and are finding what they're looking for more often.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("shows searches as increased when the prior period has no searches", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: { value: 10, previous_value: 0 },
        no_result_rate: {
          value: 20,
          previous_value: null,
          exceeds_threshold: true,
        },
      },
      trending: [],
      content_gaps: [],
      trending_period: "monthly",
    };

    await render(
      <template>
        <DashboardSearch @search={{search}} @period="last_30_days" />
      </template>
    );

    assert
      .dom(".db-section__subintro")
      .hasText(
        "The total number of searches has increased in the last 30 days Members are conducting more searches in your community, but the no-result rate has increased. Review the content gaps to see what's missing."
      );
  });
});
