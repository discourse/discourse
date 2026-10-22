import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiModelNew from "discourse/plugins/discourse-ai/discourse/components/ai-model-new";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

module("Integration | Component | AiModelNew", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );
  });

  test("links each type card to its guide", async function (assert) {
    const empty = { content: [], resultSetMeta: { presets: [] } };

    await render(
      <template>
        <AiModelNew
          @decisionModels={{empty}}
          @embeddings={{empty}}
          @llms={{empty}}
        />
      </template>
    );

    assert
      .dom("[data-model-type='llm'] .admin-section-landing-item__description a")
      .hasAttribute("href", /\/319903$/);
    assert
      .dom(
        "[data-model-type='embedding'] .admin-section-landing-item__description a"
      )
      .hasAttribute("href", /\/259603$/);
    assert
      .dom(
        "[data-model-type='decision'] .admin-section-landing-item__description a"
      )
      .hasAttribute("href", /\/414738$/);
  });
});
