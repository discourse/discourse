import { tracked } from "@glimmer/tracking";
import { click, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiHelperCustomPrompt from "discourse/plugins/discourse-ai/discourse/components/ai-helper-custom-prompt";

class TestState {
  @tracked value = "test";
}

module("Integration | Component | ai-helper-custom-prompt", function (hooks) {
  setupRenderingTest(hooks);

  async function renderPrompt(submit) {
    const state = new TestState();
    await render(
      <template>
        <AiHelperCustomPrompt @value={{state.value}} @submit={{submit}} />
      </template>
    );
  }

  test("calls @submit when the form is submitted", async function (assert) {
    let submitted = 0;
    await renderPrompt(() => (submitted += 1));

    await triggerEvent(".ai-custom-prompt", "submit");

    assert.strictEqual(submitted, 1, "called @submit once");
  });

  test("calls @submit when the submit button is clicked", async function (assert) {
    let submitted = 0;
    await renderPrompt(() => (submitted += 1));

    await click(".ai-custom-prompt__submit");

    assert.strictEqual(submitted, 1, "called @submit once");
  });
});
