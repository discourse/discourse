import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiFeatures from "discourse/plugins/discourse-ai/discourse/components/ai-features";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

function aiFeaturesPayload(llmModel) {
  return {
    ai_features: [
      {
        id: 1,
        module_name: "summarization",
        module_enabled: true,
        features: [
          {
            name: "topic_summaries",
            agents: [],
            llm_models: [llmModel],
            enabled: true,
          },
        ],
      },
    ],
  };
}

module("Integration | Component | AiFeatures", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );

    pretender.get("/admin/plugins/discourse-ai/ai-llms.json", () => {
      return response({
        ai_llms: [
          { id: 1, display_name: "GPT-5" },
          { id: 2, display_name: "Claude" },
        ],
      });
    });

    pretender.get("/admin/config/site_settings.json", () => {
      return response({
        site_settings: [
          {
            setting: "ai_default_llm_model",
            value: "1",
            default: "",
            type: "enum",
          },
        ],
      });
    });
  });

  test("refreshes rendered LLM links after saving a new default LLM", async function (assert) {
    let aiFeaturesRequestCount = 0;

    pretender.get("/admin/plugins/discourse-ai/ai-features", () => {
      aiFeaturesRequestCount += 1;

      if (aiFeaturesRequestCount === 1) {
        return response(aiFeaturesPayload({ id: 1, name: "GPT-5" }));
      }

      return response(aiFeaturesPayload({ id: 2, name: "Claude" }));
    });

    pretender.put("/admin/site_settings/ai_default_llm_model", () => {
      return response({});
    });

    const store = this.owner.lookup("service:store");
    this.features = (await store.findAll("ai-feature")).content;

    await render(
      <template><AiFeatures @features={{this.features}} /></template>
    );

    assert
      .dom(
        ".ai-feature-card[data-feature-name='topic_summaries'] .ai-feature-card__llm-link"
      )
      .hasText("GPT-5", "renders the initial LLM from the route payload");

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");
    await selector.expand();
    await selector.selectRowByValue("2");
    await settled();

    assert.strictEqual(
      aiFeaturesRequestCount,
      2,
      "reloads the AI features after the default LLM save succeeds"
    );
    assert
      .dom(
        ".ai-feature-card[data-feature-name='topic_summaries'] .ai-feature-card__llm-link"
      )
      .hasText(
        "Claude",
        "updates the rendered LLM link from the refreshed payload"
      );
  });
});
