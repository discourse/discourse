import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import AiFeaturesFeatureRow from "discourse/plugins/discourse-ai/discourse/components/ai-features-feature-row";

module("Integration | Component | AiFeaturesFeatureRow", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.afterEach(() => setPrefix(""));

  test("renders deduplicated prefix-aware group links", async function (assert) {
    setPrefix("/forum");
    const feature = {
      name: "test_feature",
      enabled: true,
      llm_models: [],
      agents: [
        {
          id: 1,
          name: "First agent",
          allowed_groups: [
            { id: 10, name: "team" },
            { id: 11, name: "staff" },
          ],
        },
        {
          id: 2,
          name: "Second agent",
          allowed_groups: [{ id: 10, name: "team" }],
        },
      ],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @name="Test feature"
              @showGroups={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert
      .dom(".ai-features-feature-row__backend")
      .doesNotExist("does not label features without backend metadata");
    assert
      .dom(".ai-features-feature-row__agent-link")
      .exists({ count: 2 }, "links every agent");
    assert
      .dom(".ai-features-feature-row__group-list li")
      .exists({ count: 2 }, "renders each group once");
    assert
      .dom('.ai-features-feature-row__group-list a[data-group-card="team"]')
      .exists({ count: 1 }, "deduplicates repeated groups")
      .hasClass("mention-group", "uses the standard group mention styling")
      .hasAttribute("href", "/forum/g/team", "uses the prefix-aware path");
    assert
      .dom(".ai-features-feature-row__enabled .d-toggle-switch")
      .doesNotExist("has no toggle without an enabling setting");
    assert
      .dom(".ai-features-feature-row__enabled")
      .doesNotExist("has no enabled column unless asked");
  });

  test("leaves features that follow their module without a status", async function (assert) {
    const feature = {
      name: "proofread",
      enabled: true,
      agents: [],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @moduleEnabled={{true}}
              @name="Proofread"
              @showEnabled={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert.dom(".ai-features-status").doesNotExist();
  });

  test("shows features that are off within an enabled module", async function (assert) {
    const feature = {
      name: "highlights",
      enabled: false,
      agents: [],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @moduleEnabled={{true}}
              @name="Highlights"
              @showEnabled={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert.dom(".ai-features-status").hasAttribute("data-status", "off");
  });

  test("toggles the feature's enabling setting", async function (assert) {
    let savedValue;
    let changed = false;
    pretender.put(
      "/admin/site_settings/ai_summary_gists_enabled",
      (request) => {
        savedValue = new URLSearchParams(request.requestBody).get(
          "ai_summary_gists_enabled"
        );
        return response({});
      }
    );

    const feature = {
      name: "gists",
      enabled: false,
      enabled_setting: {
        name: "ai_summary_gists_enabled",
        value: false,
        can_enable: true,
      },
      agents: [],
      llm_models: [],
    };
    const onChange = () => (changed = true);

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @name="Gists"
              @onChange={{onChange}}
              @showEnabled={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert
      .dom(".ai-feature-setting-toggle")
      .hasAria("checked", "false")
      .hasAria(
        "label",
        i18n("discourse_ai.features.toggle", { name: "Gists" })
      );

    await click(".ai-feature-setting-toggle");

    assert.strictEqual(savedValue, "true", "saves the flipped value");
    assert.true(changed, "notifies the parent so it can reload");
  });

  test("disables the feature toggle when asked", async function (assert) {
    const feature = {
      name: "gists",
      enabled: false,
      enabled_setting: {
        name: "ai_summary_gists_enabled",
        value: true,
        can_enable: true,
      },
      agents: [],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @name="Gists"
              @showEnabled={{true}}
              @toggleDisabled={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert.dom(".ai-feature-setting-toggle").isDisabled();
  });

  test("shows when the setting cannot be enabled yet", async function (assert) {
    const feature = {
      name: "gists",
      enabled: false,
      enabled_setting: {
        name: "ai_summary_gists_enabled",
        value: false,
        can_enable: false,
      },
      agents: [],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @name="Gists"
              @showEnabled={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert.dom(".ai-feature-setting-toggle").doesNotExist();
    assert
      .dom(".ai-features-status")
      .hasAttribute("data-status", "setup")
      .hasText(i18n("discourse_ai.features.status.needs_setup"));
  });

  test("explains what a feature needs before it can work", async function (assert) {
    const feature = {
      name: "post_illustrator",
      enabled: false,
      needs_setup: "no_image_generation_tool",
      access_by_agent_groups: true,
      shared_with: [],
      agents: [{ id: 1, name: "Post illustrator", allowed_groups: [] }],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @moduleEnabled={{true}}
              @name="Post illustrator"
              @showEnabled={{true}}
              @showGroups={{true}}
              @whoCanUse={{true}}
            />
          </tbody>
        </table>
      </template>
    );

    assert.dom(".ai-features-status").hasAttribute("data-status", "setup");
    assert
      .dom(".ai-features-feature-row__setup-note")
      .hasText(
        i18n("discourse_ai.features.status_notes.no_image_generation_tool")
      );
    assert
      .dom(".ai-feature-agent-groups__edit")
      .exists("who can use it is editable");
  });

  test("leaves agent and LLM empty for features without an agent", async function (assert) {
    const feature = {
      name: "related_topics",
      enabled: true,
      agentless: true,
      agents: [],
      llm_models: [],
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow @feature={{feature}} @name="Related topics" />
          </tbody>
        </table>
      </template>
    );

    assert
      .dom(".ai-features-feature-row")
      .doesNotIncludeText(i18n("discourse_ai.features.no_agent"))
      .doesNotIncludeText(i18n("discourse_ai.features.no_llm"));
  });

  test("shows a decision model working alongside the agent", async function (assert) {
    const feature = {
      name: "locale_detector",
      enabled: true,
      agents: [{ id: 1, name: "Locale detector" }],
      llm_models: [{ id: 2, name: "Fallback LLM" }],
      decision_model: { id: 3, display_name: "Fast decisions" },
    };

    await render(
      <template>
        <table>
          <tbody>
            <AiFeaturesFeatureRow
              @feature={{feature}}
              @name="Locale detector"
            />
          </tbody>
        </table>
      </template>
    );

    assert
      .dom(".ai-features-feature-row__agent-link")
      .hasText("Locale detector", "keeps the fallback agent");
    assert
      .dom(".ai-features-feature-row__llm-link")
      .hasText("Fallback LLM", "keeps the agent's LLM");
    assert
      .dom(
        ".ai-features-feature-row__llm .ai-features-feature-row__decision-model-link"
      )
      .hasText("Fast decisions", "lists the decision model with the models");
  });

  for (const backend of ["agent", "decision_model", "classification_model"]) {
    test(`renders the ${backend} configuration`, async function (assert) {
      const feature = {
        name: "sentiment",
        enabled: true,
        backend,
        ready: true,
        agents: [{ id: 1, name: "Classifier" }],
        llm_models: [{ id: 2, name: "Classifier LLM" }],
        decision_model: { id: 3, display_name: "Fast decisions" },
        classification_model: { model_name: "dedicated/sentiment" },
      };

      await render(
        <template>
          <table>
            <tbody>
              <AiFeaturesFeatureRow @feature={{feature}} @name="Sentiment" />
            </tbody>
          </table>
        </template>
      );

      assert
        .dom(".ai-features-feature-row__backend")
        .includesText(
          i18n(`discourse_ai.features.backends.${backend}`),
          "labels the selected backend"
        );
      assert
        .dom(".ai-features-feature-row__not-configured")
        .doesNotExist("does not warn when configured");

      if (backend === "agent") {
        assert
          .dom(".ai-features-feature-row__agent-link")
          .hasText("Classifier", "shows the selected agent");
        assert
          .dom(".ai-features-feature-row__llm-link")
          .hasText("Classifier LLM", "shows the effective LLM");
      } else {
        assert
          .dom(".ai-features-feature-row__agent-link")
          .doesNotExist("does not show irrelevant agents");
        assert
          .dom(".ai-features-feature-row__llm-link")
          .doesNotExist("does not show irrelevant LLMs");
        assert
          .dom(
            `.ai-features-feature-row__${backend === "decision_model" ? "decision-model" : "classification-model"}-link`
          )
          .hasText(
            backend === "decision_model"
              ? "Fast decisions"
              : "dedicated/sentiment",
            "links the configured model"
          );
      }
    });

    test(`shows unconfigured ${backend} separately from enabled`, async function (assert) {
      const feature = {
        name: "sentiment",
        backend,
        ready: false,
        enabled: true,
        agents: [],
        llm_models: [],
      };

      await render(
        <template>
          <table>
            <tbody>
              <AiFeaturesFeatureRow @feature={{feature}} @name="Sentiment" />
            </tbody>
          </table>
        </template>
      );

      assert
        .dom(".ai-features-feature-row__not-configured")
        .hasText(
          i18n("discourse_ai.features.not_configured"),
          "shows configuration readiness"
        );
      assert
        .dom(".ai-features-status")
        .doesNotExist("does not conflate readiness with enablement");

      if (backend !== "agent") {
        assert
          .dom(".ai-features-feature-row")
          .doesNotIncludeText(
            i18n("discourse_ai.features.no_llm"),
            "no missing LLM warning"
          );
        assert
          .dom(".ai-features-feature-row")
          .doesNotIncludeText(
            i18n("discourse_ai.features.no_agent"),
            "no missing agent warning"
          );
      }
    });
  }
});
