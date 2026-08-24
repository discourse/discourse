import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiAutomationFilter from "discourse/plugins/discourse-ai/discourse/connectors/above-review-filters/ai-automation-filter";

module("Integration | Component | AiAutomationFilter", function (hooks) {
  setupRenderingTest(hooks);

  test("lists AI automations and updates the dedicated filter", async function (assert) {
    this.currentUser.set("ai_triage_automations", [
      { id: 21, name: "Classic triage" },
      { id: 34, name: "Agent triage" },
    ]);
    const outletArgs = {
      additionalFilters: { ai_triage_automation_id: 21 },
    };

    await render(
      <template><AiAutomationFilter @outletArgs={{outletArgs}} /></template>
    );

    assert
      .dom(".ai-automation-filter .filter-label")
      .hasText("AI automation", "it labels the filter");

    const automationSelector = selectKit(".ai-automation-filter .combo-box");
    await automationSelector.expand();
    assert.deepEqual(
      automationSelector.noneRow().label(),
      "(all AI automations)",
      "it offers all AI automations"
    );
    assert.deepEqual(
      automationSelector.rowByValue(21).label(),
      "Classic triage",
      "it lists the classic triage automation"
    );
    assert.deepEqual(
      automationSelector.rowByValue(34).label(),
      "Agent triage",
      "it lists the agent triage automation"
    );

    await automationSelector.selectRowByValue(34);

    assert.strictEqual(
      outletArgs.additionalFilters.ai_triage_automation_id,
      34,
      "it writes the stable automation ID to the dedicated filter"
    );
  });
});
