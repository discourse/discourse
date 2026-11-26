import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AiAutomaticImageTools from "discourse/plugins/discourse-ai/discourse/components/ai-automatic-image-tools";

module("Integration | Component | AiAutomaticImageTools", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("lists the automatically selected image tools with editor links", async function (assert) {
    const tools = [
      { id: 10, name: "Image generator A" },
      { id: 11, name: "Image generator B" },
    ];

    await render(
      <template><AiAutomaticImageTools @tools={{tools}} /></template>
    );

    assert
      .dom(".ai-automatic-image-tools__description")
      .hasText(i18n("discourse_ai.ai_agent.automatic_image_tools"));
    assert.dom(".ai-automatic-image-tools__list a").exists({ count: 2 });
    assert
      .dom(".ai-automatic-image-tools__list li:first-child a")
      .hasText(tools[0].name);
    assert
      .dom(".ai-automatic-image-tools__list li:last-child a")
      .hasText(tools[1].name);
  });

  test("explains when no image tools are enabled", async function (assert) {
    const tools = [];

    await render(
      <template><AiAutomaticImageTools @tools={{tools}} /></template>
    );

    assert
      .dom(".ai-automatic-image-tools__empty")
      .hasText(i18n("discourse_ai.ai_agent.no_image_tools"));
    assert.dom(".ai-automatic-image-tools__list a").doesNotExist();
  });
});
