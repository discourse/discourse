import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSearch from "discourse/admin/components/dashboard/search";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

const startDate = new Date("2026-04-01");
const endDate = new Date("2026-04-30");

module("Integration | Component | Dashboard | Search", function (hooks) {
  setupRenderingTest(hooks);

  test("has a complete headline lookup table", function (assert) {
    const prefix = "admin.dashboard.sections.search.headline";
    const headlineTranslations = I18n.lookup(prefix);
    const scenarios = Object.fromEntries(
      Object.entries(headlineTranslations).filter(([key]) => key !== "cta")
    );

    assert.deepEqual(
      Object.keys(scenarios).sort(),
      [
        "down_down",
        "down_flat",
        "down_unavailable",
        "down_up",
        "flat_down",
        "flat_flat",
        "flat_unavailable",
        "flat_up",
        "no_data",
        "unavailable_down",
        "unavailable_flat",
        "unavailable_up",
        "up_down",
        "up_flat",
        "up_unavailable",
        "up_up",
      ],
      "contains every supported direction combination exactly once"
    );
    assert.true(
      Object.values(scenarios).every(
        ({ title, summary }) =>
          typeof title === "string" && typeof summary === "string"
      ),
      "every scenario has a complete headline and summary"
    );
    assert.deepEqual(
      Object.keys(headlineTranslations.cta),
      ["content_gaps"],
      "contains the reusable search CTA"
    );
  });

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

  test("treats no prior searches as a zero baseline", async function (assert) {
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
