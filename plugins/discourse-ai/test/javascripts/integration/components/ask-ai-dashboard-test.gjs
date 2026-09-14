import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AskAiDashboard from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai";

module("Integration | Component | AskAiDashboard", function (hooks) {
  setupRenderingTest(hooks);

  test("renders metrics, activity, and outcomes", async function (assert) {
    const data = {
      start_date: "2026-09-01",
      end_date: "2026-09-03",
      daily_asks: [
        { x: "2026-09-01", y: 8 },
        { x: "2026-09-02", y: 0 },
        { x: "2026-09-03", y: 4 },
      ],
      questions: 12,
      askers: 4,
      average_first_answer_ms: 1500,
      outcomes: [
        { outcome: "answered", count: 8 },
        { outcome: "no_answer", count: 3 },
        { outcome: "failed", count: 1 },
        { outcome: "cancelled", count: 0 },
        { outcome: "pending", count: 0 },
      ],
    };
    await render(<template><AskAiDashboard @data={{data}} /></template>);

    assert.dom(".ask-ai-dashboard__metric").exists({ count: 3 });
    assert
      .dom(".ask-ai-dashboard__activity h3 a")
      .doesNotExist("keeps headings unlinked without Data Explorer");
    assert
      .dom(".ask-ai-dashboard .db-section__subheader")
      .exists("uses the shared summary header");
    assert
      .dom(".ask-ai-dashboard .db-section__row")
      .exists({ count: 1 }, "groups content in a shared dashboard row");
    assert
      .dom(".ask-ai-dashboard .db-section__row > .db-section__row-block")
      .exists({ count: 2 }, "uses shared blocks for the chart and outcomes");
    assert
      .dom(".ask-ai-dashboard .db-section__row-block-title")
      .exists({ count: 2 }, "uses consistent block headings");
    assert
      .dom("[data-outcome]")
      .exists({ count: 3 }, "only shows outcomes that occurred");
    assert
      .dom('[data-outcome="cancelled"]')
      .doesNotExist("hides zero cancellations");
    assert
      .dom('[data-outcome="pending"]')
      .doesNotExist("hides zero incomplete asks");
    assert
      .dom('[data-outcome="answered"] dd')
      .hasText("8 66.7%", "shows the count and share of all asks");
    assert
      .dom(".ask-ai-dashboard__chart canvas")
      .exists("renders the activity chart");
    assert
      .dom(".ask-ai-dashboard__chart tbody tr")
      .exists(
        { count: 3 },
        "provides accessible daily values including zero days"
      );
    assert.strictEqual(
      find(".ask-ai-dashboard__chart .sr-only").offsetHeight,
      1,
      "clips the accessible data table without extending the page"
    );
    await triggerEvent(
      '[data-metric="latency"] .fk-d-tooltip__trigger',
      "pointermove"
    );
    assert
      .dom(".fk-d-tooltip__content")
      .hasText(i18n("admin.dashboard.ask_ai.latency_tooltip"));
    await triggerEvent(
      '[data-metric="latency"] .fk-d-tooltip__trigger',
      "pointerleave"
    );
    assert
      .dom(".db-section__subintro h3")
      .hasText(i18n("admin.dashboard.ask_ai.summary", { count: 12 }));
    assert
      .dom('[data-metric="questions"] dd')
      .hasText("12", "uses the supplied Ask count");
    assert
      .dom('[data-metric="latency"] dd')
      .hasText("1.5 s", "converts milliseconds to seconds");
  });

  test("links both headings to date-filtered Data Explorer queries", async function (assert) {
    const data = {
      start_date: "2026-09-01",
      end_date: "2026-09-09",
      questions: 1,
      askers: 1,
      outcomes: [],
      daily_asks: [],
      data_explorer_query_ids: { activity: -45, outcomes: -46 },
    };
    await render(<template><AskAiDashboard @data={{data}} /></template>);
    const params = encodeURIComponent(
      JSON.stringify({ start_date: data.start_date, end_date: data.end_date })
    );
    assert
      .dom(".ask-ai-dashboard__chart h3 a")
      .hasAttribute(
        "href",
        `/admin/plugins/discourse-data-explorer/queries/-45?params=${params}`,
        "passes the dates to the activity query"
      );
    assert
      .dom(".ask-ai-dashboard__outcomes h3 a")
      .hasAttribute(
        "href",
        `/admin/plugins/discourse-data-explorer/queries/-46?params=${params}`,
        "passes the dates to the outcomes query"
      );
  });

  test("distinguishes missing latency from zero latency", async function (assert) {
    const data = {
      questions: 0,
      askers: 0,
      average_first_answer_ms: null,
      outcomes: [],
    };
    await render(<template><AskAiDashboard @data={{data}} /></template>);
    assert
      .dom('[data-metric="latency"] dd')
      .hasText("—", "no answer timing is available");
    assert
      .dom(".ask-ai-dashboard__activity")
      .doesNotExist("hides the chart and zero outcomes");
    assert
      .dom(".db-section__subheader .db-section__subintro h3")
      .hasText(
        i18n("admin.dashboard.ask_ai.empty"),
        "explains the empty period"
      );
  });

  test("shows a loading failure instead of zero metrics", async function (assert) {
    await render(<template><AskAiDashboard @fetchError={{true}} /></template>);
    assert.dom('[role="alert"]').exists("reports the failure");
    assert
      .dom('[data-metric="questions"]')
      .doesNotExist("does not present a failed request as zero activity");
  });
});
