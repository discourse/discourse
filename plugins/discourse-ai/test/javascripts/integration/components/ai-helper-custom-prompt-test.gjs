import { tracked } from "@glimmer/tracking";
import { render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiHelperCustomPrompt from "discourse/plugins/discourse-ai/discourse/components/ai-helper-custom-prompt";

class TestState {
  @tracked value = "test";
}

module("Integration | Component | ai-helper-custom-prompt", function (hooks) {
  setupRenderingTest(hooks);

  test("does not submit when Enter is pressed during IME composition", async function (assert) {
    let submitted = false;
    const submit = () => (submitted = true);
    const state = new TestState();

    await render(
      <template>
        <AiHelperCustomPrompt @value={{state.value}} @submit={{submit}} />
      </template>
    );

    await triggerKeyEvent(".ai-custom-prompt__input", "keydown", "Enter", {
      isComposing: true,
    });

    assert.false(submitted, "does not submit during IME composition");
  });

  test("submits when Enter is pressed outside of IME composition", async function (assert) {
    let submitted = false;
    const submit = () => (submitted = true);
    const state = new TestState();

    await render(
      <template>
        <AiHelperCustomPrompt @value={{state.value}} @submit={{submit}} />
      </template>
    );

    await triggerKeyEvent(".ai-custom-prompt__input", "keydown", "Enter");

    assert.true(submitted, "submits on Enter without IME composition");
  });
});
