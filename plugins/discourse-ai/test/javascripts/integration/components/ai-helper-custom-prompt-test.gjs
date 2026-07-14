import { tracked } from "@glimmer/tracking";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiHelperCustomPrompt from "discourse/plugins/discourse-ai/discourse/components/ai-helper-custom-prompt";

class TestState {
  @tracked value = "test";
}

module("Integration | Component | AiHelperCustomPrompt", function (hooks) {
  setupRenderingTest(hooks);

  async function renderPrompt(submit, initialValue = "test") {
    const state = new TestState();
    state.value = initialValue;
    await render(
      <template>
        <AiHelperCustomPrompt @value={{state.value}} @submit={{submit}} />
      </template>
    );
  }

  test("submitting the form calls @submit", async function (assert) {
    let submitted = 0;
    await renderPrompt(() => (submitted += 1));

    await triggerEvent(".ai-custom-prompt", "submit");

    assert.strictEqual(submitted, 1, "called @submit once");
  });

  test("submit is skipped when the input is empty", async function (assert) {
    let submitted = 0;
    await renderPrompt(() => (submitted += 1), "");

    await triggerEvent(".ai-custom-prompt", "submit");

    assert.strictEqual(submitted, 0, "did not call @submit");
  });
});
