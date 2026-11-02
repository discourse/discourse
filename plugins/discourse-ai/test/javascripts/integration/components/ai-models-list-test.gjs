import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { usageRoute } from "discourse/plugins/discourse-ai/discourse/components/ai-llm-usages";
import AiModelsList, {
  modelTypes,
} from "discourse/plugins/discourse-ai/discourse/components/ai-models-list";

class FilterState {
  @tracked type = null;
}

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

module("Integration | Component | AiModelsList", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
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
    this.embeddings = { content: [], resultSetMeta: { presets: [] } };

    await render(
      <template>
        <AiModelsList @embeddings={{this.embeddings}} @llms={{this.llms}} />
      </template>
    );

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

  test("lists every model type and filters by type", async function (assert) {
    this.llms = {
      content: [
        {
          id: 1,
          name: "test-model",
          display_name: "Test model",
          provider: "fake",
        },
      ],
      resultSetMeta: { presets: [] },
    };
    this.embeddings = {
      content: [{ id: 2, display_name: "Test embedding", provider: "open_ai" }],
      resultSetMeta: { presets: [] },
    };
    this.decisionModels = {
      content: [
        { id: 3, display_name: "Test decision", provider: "system_one" },
        {
          id: -1,
          display_name: "Seeded decision",
          provider: "system_one",
          seeded: true,
        },
      ],
      resultSetMeta: { presets: [] },
    };
    const state = new FilterState();

    await render(
      <template>
        <AiModelsList
          @decisionModels={{this.decisionModels}}
          @embeddings={{this.embeddings}}
          @llms={{this.llms}}
          @type={{state.type}}
        />
      </template>
    );

    assert.dom(".ai-models-list__row[data-model-type='llm']").exists();
    assert.dom(".ai-models-list__row[data-model-type='embedding']").exists();
    assert
      .dom(".ai-models-list__row[data-model-type='decision']")
      .exists({ count: 2 });
    assert
      .dom("[data-model-id='-1'] .ai-models-list__edit-button")
      .doesNotExist("seeded decision models are read-only");
    assert
      .dom(
        ".ai-models-list__row[data-model-type='embedding'] .ai-models-list__type"
      )
      .includesText("Embedding");

    state.type = "embedding";
    await settled();

    assert.dom(".ai-models-list__row").exists({ count: 1 });
    assert.dom(".ai-models-list__row[data-model-type='embedding']").exists();
  });

  test("offers decision models when none are passed", async function (assert) {
    this.llms = { content: [], resultSetMeta: { presets: [] } };
    this.embeddings = {
      content: [{ id: 2, display_name: "Test embedding", provider: "open_ai" }],
      resultSetMeta: { presets: [] },
    };

    await render(
      <template>
        <AiModelsList @embeddings={{this.embeddings}} @llms={{this.llms}} />
      </template>
    );

    assert
      .dom(".ai-models-list__type-filter option[value='decision']")
      .exists("offers the decision type even without models");
  });

  test("shows the default LLM setting only when filtered to LLMs", async function (assert) {
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

    this.llms = {
      content: [
        {
          id: 1,
          name: "test-model",
          display_name: "Test model",
          provider: "fake",
        },
      ],
      resultSetMeta: { presets: [] },
    };
    this.embeddings = { content: [], resultSetMeta: { presets: [] } };
    const state = new FilterState();

    await render(
      <template>
        <AiModelsList
          @embeddings={{this.embeddings}}
          @llms={{this.llms}}
          @type={{state.type}}
        />
      </template>
    );

    assert.dom(".ai-configure-default-llm").doesNotExist();

    state.type = "llm";
    await settled();

    assert.dom(".ai-configure-default-llm").exists();
  });
  test("model types are unconditional", function (assert) {
    assert.deepEqual(
      modelTypes(),
      ["llm", "embedding", "decision"],
      "all types are discoverable without workflow availability"
    );
  });

  test("offers model creation when every list is empty and workflows are disabled", async function (assert) {
    this.siteSettings.enable_discourse_workflows = false;
    const empty = { content: [], resultSetMeta: { presets: [] } };
    await render(
      <template>
        <AiModelsList
          @decisionModels={{empty}}
          @embeddings={{empty}}
          @llms={{empty}}
        />
      </template>
    );
    assert
      .dom(".ai-models-list__new-button")
      .exists("keeps the header creation action");
    assert
      .dom(".ai-models-list__empty-new-button")
      .exists("offers creation from the empty state");
  });
});
