import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SupportSection from "discourse/plugins/discourse-solved/admin/components/dashboard/support";

function buildData(overrides = {}) {
  return {
    category_options: [],
    kpis: {
      resolution_rate: {
        value: 72,
        previous_value: 69,
        report_type: "accepted_solutions",
        report_query: { start_date: "2026-04-01", end_date: "2026-04-30" },
      },
      staff_involvement: { value: 19, previous_value: 25 },
      avg_first_reply: { value: 11100, previous_value: 10620 },
    },
    headline: { key: "healthy", resolution_rate: 72, unanswered_count: 3 },
    topic_outcomes: { resolved: 1, in_progress: 0, unanswered: 3 },
    whos_answering: {
      rows: [{ type: "staff", count: 1, share: 100 }],
      total: 1,
    },
    response_time_distribution: {
      buckets: [
        { key: "lt_1h", count: 1, share: 100 },
        { key: "1_4h", count: 0, share: 0 },
        { key: "4_24h", count: 0, share: 0 },
        { key: "gt_24h", count: 0, share: 0 },
      ],
      trend: { direction: "flat", seconds: 0 },
    },
    ...overrides,
  };
}

const startDate = new Date("2026-04-01");
const endDate = new Date("2026-04-30");

module("Integration | Component | Dashboard | Support", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a positive resolution-rate delta", async function (assert) {
    const data = buildData();

    await render(
      <template>
        <SupportSection
          @data={{data}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-support .db-delta.--pos").hasText("+3%");
  });

  test("renders a negative resolution-rate delta", async function (assert) {
    const data = buildData({
      kpis: {
        resolution_rate: { value: 34, previous_value: 43, report_query: {} },
        staff_involvement: { value: 81, previous_value: 62 },
        avg_first_reply: { value: 51720, previous_value: 20520 },
      },
    });

    await render(
      <template>
        <SupportSection
          @data={{data}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-support .db-delta.--neg").hasText("-9%");
  });

  test("shows a placeholder when the average first reply is unknown", async function (assert) {
    const data = buildData({
      kpis: {
        resolution_rate: { value: 0, previous_value: 0, report_query: {} },
        staff_involvement: { value: 0, previous_value: 0 },
        avg_first_reply: { value: null, previous_value: null },
      },
    });

    await render(
      <template>
        <SupportSection
          @data={{data}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-support__body").exists();
    assert.dom(".db-section__metrics").includesText("—");
  });

  test("shows the category filter only when more than one support category exists", async function (assert) {
    const single = buildData({
      category_options: [{ id: 1, name: "Support" }],
    });

    await render(
      <template>
        <SupportSection
          @data={{single}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-support__filter").doesNotExist("hidden with one category");

    const multiple = buildData({
      category_options: [
        { id: 1, name: "Support" },
        { id: 2, name: "Help" },
      ],
    });

    await render(
      <template>
        <SupportSection
          @data={{multiple}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-support__filter").exists("shown with multiple categories");
  });
});
