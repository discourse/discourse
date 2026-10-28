import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AiFeatureCard from "discourse/plugins/discourse-ai/discourse/components/ai-feature-card";

module("Integration | Component | AiFeatureCard", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.afterEach(() => setPrefix(""));

  test("renders deduplicated prefix-aware group card links", async function (assert) {
    setPrefix("/forum");
    this.feature = {
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
        <AiFeatureCard
          @feature={{this.feature}}
          @localizedFeatureName="Test feature"
          @showGroups={{true}}
        />
      </template>
    );

    assert
      .dom(".ai-feature-card__backend")
      .doesNotExist("does not change cards without backend metadata");
    assert
      .dom(".ai-feature-card__item-groups li")
      .exists({ count: 2 }, "renders each group once");
    assert
      .dom('.ai-feature-card__item-groups a[data-group-card="team"]')
      .exists({ count: 1 }, "deduplicates repeated groups")
      .hasClass("user-group", "uses the standard group link class")
      .hasClass("trigger-group-card", "triggers the standard group card")
      .hasClass("mention-group", "uses the standard group mention styling")
      .hasAttribute(
        "href",
        "/forum/g/team",
        "uses the prefix-aware group path"
      );
    assert
      .dom('.ai-feature-card__item-groups a[data-group-card="staff"]')
      .exists({ count: 1 }, "renders the other group")
      .hasAttribute("href", "/forum/g/staff", "prefixes every group path");
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
      await render(<template><AiFeatureCard @feature={{feature}} /></template>);
      assert
        .dom(".ai-feature-card__backend")
        .includesText(
          i18n(`discourse_ai.features.backends.${backend}`),
          "labels the selected backend"
        );
      assert
        .dom(".ai-feature-card__readiness")
        .doesNotExist("does not warn when configured");
      if (backend === "agent") {
        assert
          .dom(".ai-feature-card__agent-link")
          .hasText("Classifier", "shows the selected agent");
        assert
          .dom(".ai-feature-card__llm-link")
          .hasText("Classifier LLM", "shows the effective LLM");
      } else {
        assert
          .dom(".ai-feature-card__agent")
          .doesNotExist("does not show irrelevant agents");
        assert
          .dom(".ai-feature-card__llm")
          .doesNotExist("does not show irrelevant LLMs");
        assert
          .dom(
            `.ai-feature-card__${backend === "decision_model" ? "decision-model" : "classification-model"}-link`
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
      await render(<template><AiFeatureCard @feature={{feature}} /></template>);
      assert
        .dom(".ai-feature-card__readiness")
        .hasText(
          i18n("discourse_ai.features.not_configured"),
          "shows configuration readiness"
        );
      assert
        .dom(".ai-feature-card__feature-name")
        .doesNotIncludeText(
          "disabled",
          "does not conflate readiness with enablement"
        );
      if (backend !== "agent") {
        assert
          .dom(".ai-feature-card")
          .doesNotIncludeText(
            i18n("discourse_ai.features.no_llm"),
            "no missing LLM warning"
          );
        assert
          .dom(".ai-feature-card")
          .doesNotIncludeText(
            i18n("discourse_ai.features.no_agent"),
            "no missing agent warning"
          );
      }
    });
  }
});
