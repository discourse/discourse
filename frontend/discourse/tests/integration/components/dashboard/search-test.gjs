import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSearch from "discourse/admin/components/dashboard/search";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const startDate = new Date("2026-04-01");
const endDate = new Date("2026-04-30");

module("Integration | Component | Dashboard | Search", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the PM headline when searches increase and the no-result rate declines", async function (assert) {
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

  test("renders the PM headline when searches and the no-result rate increase", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 120,
          previous_value: 100,
          percent_change: 20,
        },
        no_result_rate: {
          value: 12,
          previous_value: 10,
          point_change: 2,
          exceeds_threshold: true,
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
        "The total number of searches has increased in the last 30 days",
        "Members are conducting more searches in your community, but the no-result rate has increased. Review the content gaps to see what's missing.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when searches increase and the no-result rate stays flat", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 120,
          previous_value: 100,
          percent_change: 20,
        },
        no_result_rate: {
          value: 10,
          previous_value: 10,
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
        "The total number of searches has increased in the last 30 days",
        "Members are conducting more searches in your community, but the no-result rate is flat. Review the content gaps to see what's missing.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when the no-result rate and searches decrease", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 80,
          previous_value: 100,
          percent_change: -20,
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
        "The no-result rate has decreased in the last 30 days",
        "Members are finding what they're looking for, and total search volume has decreased.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when the no-result rate decreases and searches stay flat", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 100,
          previous_value: 100,
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
        "The no-result rate has decreased in the last 30 days",
        "Members are finding what they're looking for, and total search volume is flat.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when searches decrease and the no-result rate increases", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 80,
          previous_value: 100,
          percent_change: -20,
        },
        no_result_rate: {
          value: 12,
          previous_value: 10,
          point_change: 2,
          exceeds_threshold: true,
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
        "Searches have decreased and the no-result rate has gone up in the last 30 days",
        "Members are conducting fewer searches in your community and are not finding what they need as often. Review the content gaps to see what's missing.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when searches decrease and the no-result rate stays flat", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 80,
          previous_value: 100,
          percent_change: -20,
        },
        no_result_rate: {
          value: 10,
          previous_value: 10,
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
        "The total number of searches has decreased in the last 30 days",
        "Members are conducting fewer searches in your community, but the no-result rate is flat.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when searches stay flat and the no-result rate increases", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 100,
          previous_value: 100,
        },
        no_result_rate: {
          value: 12,
          previous_value: 10,
          point_change: 2,
          exceeds_threshold: true,
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
        "The no-result rate has increased in the last 30 days",
        "Members are not finding what they need as often, and total search volume is holding steady. Review the content gaps to see what's missing.",
      ],
      "renders the exact scenario headline and summary"
    );
  });

  test("renders the PM headline when both metrics stay flat", async function (assert) {
    const search = {
      logging_enabled: true,
      kpis: {
        total_searches: {
          value: 100,
          previous_value: 100,
        },
        no_result_rate: {
          value: 10,
          previous_value: 10,
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
        "Search is steady in the last 30 days",
        "No meaningful change in total searches or the no-result rate.",
      ],
      "renders the exact scenario headline and summary"
    );
  });
});
