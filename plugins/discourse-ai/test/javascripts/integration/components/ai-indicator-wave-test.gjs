import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiIndicatorWave from "discourse/plugins/discourse-ai/discourse/components/ai-indicator-wave";

module("Integration | Component | ai-indicator-wave", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders an indicator wave", async function (assert) {
    await render(<template><AiIndicatorWave @loading={{true}} /></template>);
    assert.dom(".ai-indicator-wave").exists();
  });

  test("it does not render the indicator wave when loading is false", async function (assert) {
    await render(<template><AiIndicatorWave @loading={{false}} /></template>);
    assert.dom(".ai-indicator-wave").doesNotExist();
  });
});
