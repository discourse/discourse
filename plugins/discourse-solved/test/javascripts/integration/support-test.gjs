import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
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
    headline: {
      key: "healthy",
      resolution_rate: 72,
      resolution_direction: "up",
      answerers_focus: "members",
      answerers_share: 82,
      first_reply_seconds: 11100,
      first_reply_direction: "slower",
      first_reply_delta_seconds: 480,
      unanswered_count: 3,
    },
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

    assert
      .dom(".db-section__metric:first-child .db-delta.--pos")
      .hasText("+3%");
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

    assert
      .dom(".db-section__metric:first-child .db-delta.--neg")
      .hasText("-9%");
  });

  test("renders a stable tag for metrics that did not change", async function (assert) {
    const data = buildData({
      kpis: {
        resolution_rate: { value: 50, previous_value: 50, report_query: {} },
        staff_involvement: { value: 20, previous_value: 20 },
        avg_first_reply: { value: 11100, previous_value: 11100 },
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

    assert.dom(".db-section__metrics .db-pill").exists({ count: 3 });
    assert.dom(".db-section__metrics .db-delta").doesNotExist();
  });

  test("shows no delta or stable tag when the previous period has no data", async function (assert) {
    const data = buildData({
      kpis: {
        resolution_rate: { value: 40, previous_value: null, report_query: {} },
        staff_involvement: { value: 30, previous_value: null },
        avg_first_reply: { value: 11100, previous_value: null },
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

    assert.dom(".db-section__metrics .db-delta").doesNotExist();
    assert.dom(".db-section__metrics .db-pill").doesNotExist();
  });

  test("composes a trend-aware headline summary from each metric's direction", async function (assert) {
    const positive = buildData();

    await render(
      <template>
        <SupportSection
          @data={{positive}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-section__subintro p").includesText("climbed to 72%");
    assert
      .dom(".db-section__subintro p")
      .includesText("Members are handling 82%");

    const negative = buildData({
      headline: {
        key: "struggling",
        resolution_rate: 34,
        resolution_direction: "down",
        answerers_focus: "staff",
        answerers_share: 81,
        first_reply_seconds: 51720,
        first_reply_direction: "slower",
        first_reply_delta_seconds: 31200,
        unanswered_count: 47,
      },
    });

    await render(
      <template>
        <SupportSection
          @data={{negative}}
          @startDate={{startDate}}
          @endDate={{endDate}}
        />
      </template>
    );

    assert.dom(".db-section__subintro p").includesText("dropped to 34%");
    assert
      .dom(".db-section__subintro p")
      .includesText("47 topics from this period still have zero replies");
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

    assert.dom(".db-section__metrics").exists();
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
    assert.dom(".category-selector").exists();
  });

  test("prefills the selector with the persisted category selection", async function (assert) {
    const data = buildData({
      category_options: [
        { id: 1, name: "Support" },
        { id: 2, name: "Help" },
      ],
      category_ids: [1, 2],
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

    assert.strictEqual(selectKit(".category-selector").header().value(), "1,2");
  });
});
