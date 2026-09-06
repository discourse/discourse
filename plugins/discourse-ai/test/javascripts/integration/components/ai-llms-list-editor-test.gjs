import Service from "@ember/service";
import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiLlmsListEditor, {
  usageRoute,
} from "discourse/plugins/discourse-ai/discourse/components/ai-llms-list-editor";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

module("Integration | Component | AiLlmsListEditor", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );

    pretender.get("/admin/plugins/discourse-ai/ai-llms.json", () =>
      response({ ai_llms: [{ id: 1, display_name: "Test model" }] })
    );
    pretender.get("/admin/config/site_settings.json", () =>
      response({
        site_settings: [
          {
            setting: "ai_default_llm_model",
            value: "1",
            default: "",
            type: "enum",
          },
        ],
      })
    );
  });

  test("maps supported usages to their admin routes", function (assert) {
    const featureRoute = "adminPlugins.show.discourse-ai-features.edit";

    for (const type of [
      "ai_bot",
      "ai_helper",
      "ai_image_caption",
      "ai_summarization",
      "ai_embeddings_semantic_search",
    ]) {
      assert.deepEqual(
        usageRoute({ type, id: 7 }),
        { route: featureRoute, models: [7] },
        `maps ${type} to the feature editor`
      );
    }

    assert.deepEqual(usageRoute({ type: "ai_spam", id: 8 }), {
      route: "adminPlugins.show.discourse-ai-spam",
    });
    assert.deepEqual(usageRoute({ type: "ai_agent", id: 2 }), {
      route: "adminPlugins.show.discourse-ai-agents.edit",
      models: [2],
    });
    assert.deepEqual(usageRoute({ type: "automation", id: 3 }), {
      route: "adminPlugins.show.automation.edit",
      models: ["automation", 3],
    });
    assert.deepEqual(usageRoute({ type: "vision_delegate", id: 4 }), {
      route: "adminPlugins.show.discourse-ai-llms.edit",
      models: [4],
    });
    assert.deepEqual(usageRoute({ type: "ai_spam" }), {
      route: "adminPlugins.show.discourse-ai-spam",
    });
    assert.strictEqual(usageRoute({ type: "ai_bot" }), null);
    assert.strictEqual(usageRoute({ type: "ai_agent" }), null);
    assert.strictEqual(usageRoute({ type: "future_usage", id: 5 }), null);
    assert.strictEqual(usageRoute(null), null);
  });

  test("links known usages and leaves unknown targets as whole plain text labels", async function (assert) {
    this.llms = {
      content: [
        {
          id: 1,
          name: "test-model",
          display_name: "Test model",
          provider: "fake",
          used_by: [
            { type: "ai_agent", id: 2, name: "Research agent" },
            { type: "ai_bot", id: 7 },
            { type: "ai_spam", id: 8 },
            { type: "future_usage", id: 9, name: "Future integration" },
            { type: "automation", name: "Missing target" },
          ],
        },
      ],
      resultSetMeta: { presets: [] },
    };

    await render(<template><AiLlmsListEditor @llms={{this.llms}} /></template>);

    const usages = findAll(".ai-llm-list-editor__usages li");
    assert.strictEqual(usages.length, 5, "renders every usage");
    assert.strictEqual(
      usages[0].querySelector("a")?.textContent.trim(),
      "Agent (Research agent)",
      "keeps the complete agent label inside its link"
    );
    assert.strictEqual(
      usages[1].querySelector("a")?.textContent.trim(),
      "AI bot",
      "links a built-in feature"
    );
    assert.strictEqual(
      usages[2].querySelector("a")?.textContent.trim(),
      "Spam",
      "links spam to its dedicated destination"
    );
    assert.strictEqual(
      usages[3].querySelector("a"),
      null,
      "does not guess a route for an unknown usage"
    );
    assert.strictEqual(
      usages[3].textContent.trim(),
      "Future integration",
      "keeps an unknown usage readable"
    );
    assert.strictEqual(
      usages[4].querySelector("a"),
      null,
      "does not link a target with a missing ID"
    );
    assert.strictEqual(
      usages[4].textContent.trim(),
      "Automation (Missing target)",
      "keeps the malformed target label intact"
    );
  });
});
