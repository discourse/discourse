import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import Stats from "discourse/plugins/discourse-workflows/admin/components/workflows/stats";

module("Integration | Component | Workflows | Stats", function (hooks) {
  setupRenderingTest(hooks);

  test("AI usage tiles appear only when the workflow has an AI agent", async function (assert) {
    const workflow = tracked({ nodes: [{ type: "action:tag" }] });
    const stats = {
      total: 1,
      failed: 0,
      failure_rate: "0%",
      avg_duration: "100ms",
      ai_usage: { requests: 0, tokens: 0, estimated_cost: 0 },
    };

    await render(
      <template>
        <Stats @stats={{stats}} @workflow={{workflow.value}} />
      </template>
    );

    assert
      .dom(".d-stat-tiles")
      .includesText(
        i18n("discourse_workflows.stats.executions"),
        "shows execution stats"
      );
    assert
      .dom(".d-stat-tiles")
      .doesNotIncludeText(
        i18n("discourse_workflows.stats.ai_requests"),
        "hides AI usage"
      );

    workflow.value = { nodes: [{ type: "action:ai_agent" }] };
    await rerender();

    assert
      .dom(".d-stat-tiles")
      .includesText(
        i18n("discourse_workflows.stats.ai_requests"),
        "shows AI requests"
      );
    assert
      .dom(".d-stat-tiles")
      .includesText(
        i18n("discourse_workflows.stats.ai_tokens"),
        "shows AI tokens"
      );
    assert
      .dom(".d-stat-tiles")
      .includesText(
        i18n("discourse_workflows.stats.ai_estimated_cost"),
        "shows AI cost"
      );

    workflow.value = { nodes: [] };
    await rerender();

    assert
      .dom(".d-stat-tiles")
      .doesNotIncludeText(
        i18n("discourse_workflows.stats.ai_requests"),
        "hides AI usage again"
      );
  });
});
