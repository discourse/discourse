import Service from "@ember/service";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
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
        enabled_setting: {
          name: "ai_summarization_enabled",
          value: true,
          can_enable: true,
        },
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

const LLM_LINK =
  "[data-feature-name='topic_summaries'] .ai-features-feature-row__llm-link";

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
    await click(".ai-features-module-row__expand");

    assert
      .dom(LLM_LINK)
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
      .dom(LLM_LINK)
      .hasText(
        "Claude",
        "updates the rendered LLM link from the refreshed payload"
      );
  });

  test("lists modules collapsed with a status filter", async function (assert) {
    const features = [
      ...aiFeaturesPayload({ id: 1, name: "GPT-5" }).ai_features,
      {
        id: 7,
        module_name: "bot",
        module_enabled: false,
        enabled_setting: {
          name: "ai_bot_enabled",
          value: false,
          can_enable: true,
        },
        features: [{ name: "bot", agents: [], llm_models: [], enabled: true }],
      },
    ];

    await render(<template><AiFeatures @features={{features}} /></template>);

    assert
      .dom(".ai-features-module-row")
      .exists({ count: 2 }, "shows all modules by default");
    assert
      .dom(".ai-features-feature-row")
      .doesNotExist("collapses every module");
    assert
      .dom("tr[data-module-name='summarization']")
      .includesText("On · 1 of 1 feature", "summarises enabled features");
    assert
      .dom("tr[data-module-name='bot']")
      .includesText("Off", "shows disabled modules as off");

    await click(".ai-features__status-option[data-status='enabled']");

    assert
      .dom(".ai-features-module-row")
      .exists({ count: 1 }, "filters to enabled modules");
    assert
      .dom(".ai-features__status-option[data-status='enabled']")
      .hasAria("pressed", "true");

    await click(".ai-features__status-option[data-status='not enabled']");

    assert.dom(".ai-features-module-row").exists({ count: 1 });
    assert.dom("tr[data-module-name='bot']").exists();

    await click("tr[data-module-name='bot'] .ai-features-module-row__expand");

    assert
      .dom("tr[data-module-name='bot'] .ai-features-module-row__expand")
      .hasAria("expanded", "true");
    assert.dom(".ai-features-feature-row[data-feature-name='bot']").exists();
  });

  test("search reveals matching features even after their module was collapsed", async function (assert) {
    const features = aiFeaturesPayload({ id: 1, name: "GPT-5" }).ai_features;
    await render(<template><AiFeatures @features={{features}} /></template>);
    const expandButton = ".ai-features-module-row__expand";
    await click(expandButton);
    await click(expandButton);
    await fillIn(".admin-filter__input", "GPT-5");
    assert
      .dom(".ai-features-feature-row")
      .exists("search exposes the matching row");
    await fillIn(".admin-filter__input", "");
    assert
      .dom(".ai-features-feature-row")
      .doesNotExist("clearing search restores the collapsed state");
  });

  test("a promoted feature still requires setup", async function (assert) {
    const features = [
      {
        id: 2,
        module_name: "search",
        module_enabled: true,
        features: [
          {
            name: "ask_ai",
            enabled: true,
            needs_setup: true,
            agents: [],
            llm_models: [],
            enabled_setting: {
              name: "ai_discover_enabled",
              value: true,
              can_enable: true,
            },
          },
        ],
      },
    ];
    await render(<template><AiFeatures @features={{features}} /></template>);
    assert
      .dom(".ai-features-module-row")
      .includesText(
        i18n("discourse_ai.features.status.needs_setup"),
        "the parent reflects its feature's setup requirement"
      );
    assert
      .dom(".ai-feature-setting-toggle")
      .doesNotExist("does not offer a misleading enable switch");
  });

  test("switches a module from its only feature's setting", async function (assert) {
    const features = [
      {
        id: 2,
        module_name: "search",
        module_enabled: true,
        enabled_setting: null,
        features: [
          {
            name: "ask_ai",
            agents: [],
            llm_models: [],
            enabled: true,
            enabled_setting: {
              name: "ai_ask_ai_enabled",
              value: true,
              can_enable: true,
            },
          },
        ],
      },
    ];

    await render(<template><AiFeatures @features={{features}} /></template>);

    assert
      .dom("tr[data-module-name='search'] .ai-feature-setting-toggle")
      .hasAttribute("data-setting-name", "ai_ask_ai_enabled");

    await click(
      "tr[data-module-name='search'] .ai-features-module-row__expand"
    );

    assert
      .dom(".ai-features-feature-row .ai-feature-setting-toggle")
      .doesNotExist("does not repeat the switch on the feature");
    assert
      .dom(".ai-features-feature-row__enabled")
      .doesNotExist("drops the enabled column");
  });

  test("shows the status the server reports for a module", async function (assert) {
    const translation = (status, value) => ({
      id: 6,
      module_name: "translation",
      module_enabled: status?.state === "on",
      status,
      enabled_setting: {
        name: "ai_translation_enabled",
        value,
        can_enable: false,
      },
      features: [],
    });
    const row = "tr[data-module-name='translation']";

    this.set("features", [
      translation({ state: "setup", note_key: "no_languages" }, true),
    ]);
    await render(
      <template><AiFeatures @features={{this.features}} /></template>
    );

    assert
      .dom(`${row} .ai-features-status`)
      .hasAttribute("data-status", "setup")
      .hasText(i18n("discourse_ai.features.status.needs_setup"));
    assert
      .dom(`${row} .ai-features-module-row__status-note`)
      .hasText(i18n("discourse_ai.features.status_notes.no_languages"));
    assert
      .dom(`${row} .edit`)
      .hasText(i18n("discourse_ai.features.set_up"), "offers to set it up");
    assert
      .dom(`${row} .ai-feature-setting-toggle`)
      .doesNotExist("hides the switch while it needs setup, even when on");

    this.set("features", [
      translation(
        {
          state: "on",
          label_key: "on_with_languages",
          count: 2,
          note_key: "hidden_from_readers",
        },
        true
      ),
    ]);

    assert
      .dom(`${row} .ai-features-status`)
      .hasText(
        i18n("discourse_ai.features.status.on_with_languages", { count: 2 })
      );
    assert
      .dom(`${row} .ai-features-module-row__status-note`)
      .hasText(i18n("discourse_ai.features.status_notes.hidden_from_readers"));
    assert.dom(`${row} .ai-feature-setting-toggle`).exists();
  });

  test("lists what a module is missing", async function (assert) {
    const features = [
      {
        id: 3,
        module_name: "discord",
        module_enabled: false,
        status: {
          state: "setup",
          note_key: "missing",
          missing: ["app_id", "allowed_servers"],
        },
        enabled_setting: null,
        features: [],
      },
    ];

    await render(<template><AiFeatures @features={{features}} /></template>);

    assert
      .dom(
        "tr[data-module-name='discord'] .ai-features-module-row__status-note"
      )
      .hasText(
        i18n("discourse_ai.features.status_notes.missing", {
          items: [
            i18n("discourse_ai.features.setup_items.app_id"),
            i18n("discourse_ai.features.setup_items.allowed_servers"),
          ].join(", "),
        })
      );
  });

  test("links a module to where it can be set up", async function (assert) {
    const features = [
      {
        id: 9,
        module_name: "embeddings",
        module_enabled: false,
        status: { state: "setup", note_key: "no_embedding_model" },
        enabled_setting: {
          name: "ai_embeddings_enabled",
          value: false,
          can_enable: false,
        },
        features: [],
      },
    ];
    const row = "tr[data-module-name='embeddings']";

    await render(<template><AiFeatures @features={{features}} /></template>);

    assert
      .dom(`${row} a.ai-features-module-row__status-note`)
      .hasText(i18n("discourse_ai.features.status_notes.no_embedding_model"));
    assert
      .dom(`${row} a.edit`)
      .hasText(i18n("discourse_ai.features.set_up"), "sets it up there too");
  });

  test("toggles a module and reloads the features", async function (assert) {
    let savedValue;
    pretender.put(
      "/admin/site_settings/ai_summarization_enabled",
      (request) => {
        savedValue = new URLSearchParams(request.requestBody).get(
          "ai_summarization_enabled"
        );
        return response({});
      }
    );
    pretender.get("/admin/plugins/discourse-ai/ai-features", () => {
      const payload = aiFeaturesPayload({ id: 1, name: "GPT-5" });
      payload.ai_features[0].module_enabled = false;
      payload.ai_features[0].enabled_setting.value = false;
      return response(payload);
    });

    const features = aiFeaturesPayload({ id: 1, name: "GPT-5" }).ai_features;
    await render(<template><AiFeatures @features={{features}} /></template>);

    const toggle =
      "tr[data-module-name='summarization'] .ai-feature-setting-toggle";
    assert.dom(toggle).hasAria("checked", "true");

    await click(toggle);

    assert.strictEqual(savedValue, "false", "saves the flipped setting");
    assert.dom(toggle).hasAria("checked", "false", "reflects the saved state");
    assert
      .dom("tr[data-module-name='summarization']")
      .includesText("Off", "refreshes the module status");
  });

  test("filters sentiment features by decision and dedicated model names without groups", async function (assert) {
    const features = [
      {
        id: 14,
        module_name: "sentiment",
        module_enabled: true,
        features: [
          {
            name: "sentiment",
            enabled: true,
            backend: "decision_model",
            ready: true,
            agents: [],
            llm_models: [],
            decision_model: { id: 3, display_name: "Fast decisions" },
          },
          {
            name: "emotion",
            enabled: true,
            backend: "classification_model",
            ready: true,
            agents: [
              {
                id: 1,
                name: "Unused",
                allowed_groups: [{ id: 1, name: "staff" }],
              },
            ],
            llm_models: [],
            classification_model: { model_name: "dedicated/emotions" },
          },
        ],
      },
    ];
    await render(<template><AiFeatures @features={{features}} /></template>);
    await fillIn(".ai-features__controls input", "FAST DECISIONS");
    assert
      .dom(".ai-features-feature-row__groups")
      .doesNotExist("background classifiers do not display groups");
    assert
      .dom(".ai-features-feature-row")
      .exists({ count: 1 }, "only the matching decision capability remains");
    assert
      .dom('[data-feature-name="sentiment"]')
      .exists("matches decision display name case insensitively");
    await fillIn(".ai-features__controls input", "dedicated/emotions");
    assert
      .dom(".ai-features-feature-row")
      .exists({ count: 1 }, "only the matching dedicated capability remains");
    assert
      .dom('[data-feature-name="emotion"]')
      .exists("matches the dedicated model identifier");
  });
});
