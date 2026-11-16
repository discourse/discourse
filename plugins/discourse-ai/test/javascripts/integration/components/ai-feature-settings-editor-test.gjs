import { findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import form from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import { getSettingGroupsForFeature } from "discourse/plugins/discourse-ai/discourse/lib/ai-feature-setting-groups";
import FeatureEditor from "discourse/plugins/discourse-ai/discourse/templates/admin-plugins/show/discourse-ai-features/edit";

module(
  "Integration | Component | AI feature settings editor",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("keeps backend guidance beside the last active section using that backend", async function (assert) {
      const settings = [];
      for (const type of ["sentiment", "emotion"]) {
        const enabled =
          type === "sentiment"
            ? "ai_sentiment_enabled"
            : "ai_sentiment_emotion_enabled";
        const strategy = `ai_sentiment_${type}_classification_strategy`;
        settings.push(
          SiteSetting.create({ setting: enabled, type: "bool", value: true }),
          SiteSetting.create({
            setting: strategy,
            type: "enum",
            value: "decision_model",
            valid_values: ["agent", "decision_model", "classification_model"],
            depends_on: [enabled],
            depends_behavior: "hidden",
          }),
          SiteSetting.create({
            setting: `ai_sentiment_${type}_decision_model`,
            type: "enum",
            value: "1",
            valid_values: ["1"],
            depends_on: [enabled, strategy],
            depends_on_values: { [strategy]: ["decision_model"] },
            depends_behavior: "hidden",
          })
        );
      }
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );
      controller.settings = settings;
      const model = {
        module_name: "sentiment",
        feature_settings: settings,
        settingGroups: getSettingGroupsForFeature("sentiment"),
        formData: Object.fromEntries(
          settings.map((setting) => [setting.setting, setting.value])
        ),
      };
      await render(
        <template>
          <FeatureEditor @controller={{controller}} @model={{model}} />
        </template>
      );
      const [sentimentSection, emotionSection] = findAll(".form-kit__section");
      const assertDecisionAfter = (section, message) => {
        assert
          .dom(".ai-feature-editor__model-change-warning")
          .exists({ count: 1 }, "shows the shared warning exactly once");
        assert
          .dom(".ai-feature-editor__decision-models-link")
          .exists(
            { count: 1 },
            "shows the shared management link exactly once"
          );
        assert
          .dom(section.nextElementSibling)
          .hasClass("ai-feature-editor__model-change-warning", message);
        assert
          .dom(section.nextElementSibling.nextElementSibling)
          .hasClass(
            "ai-feature-editor__decision-models-link",
            "management follows the applicable model warning"
          );
      };
      const assertDedicatedAfter = (section, message) => {
        assert
          .dom(".ai-feature-editor__dedicated-link")
          .exists({ count: 1 }, "shows dedicated configuration exactly once")
          .hasText(
            i18n("discourse_ai.features.sentiment.configure_dedicated"),
            "labels dedicated endpoint configuration"
          );
        assert
          .dom(section.nextElementSibling)
          .hasClass("ai-feature-editor__dedicated-description", message);
      };

      assertDecisionAfter(
        emotionSection,
        "both decision classifiers share guidance after the last model controls"
      );
      await form().field("ai_sentiment_emotion_enabled").toggle();
      assertDecisionAfter(
        sentimentSection,
        "sentiment-only guidance is not attached to disabled emotion"
      );
      await form().field("ai_sentiment_emotion_enabled").toggle();
      await form().field("ai_sentiment_enabled").toggle();
      assertDecisionAfter(
        emotionSection,
        "emotion-only guidance stays beside emotion"
      );
      await form().field("ai_sentiment_enabled").toggle();
      await form()
        .field("ai_sentiment_sentiment_classification_strategy")
        .fillIn("classification_model");
      assertDedicatedAfter(
        sentimentSection,
        "dedicated sentiment guidance stays with sentiment"
      );
      assertDecisionAfter(
        emotionSection,
        "decision emotion guidance stays with emotion in mixed mode"
      );
      await form()
        .field("ai_sentiment_sentiment_classification_strategy")
        .fillIn("decision_model");
      await form()
        .field("ai_sentiment_emotion_classification_strategy")
        .fillIn("classification_model");
      assertDecisionAfter(
        sentimentSection,
        "decision sentiment guidance stays with sentiment in mixed mode"
      );
      assertDedicatedAfter(
        emotionSection,
        "dedicated emotion guidance stays with emotion"
      );
      await form()
        .field("ai_sentiment_sentiment_classification_strategy")
        .fillIn("classification_model");
      assertDedicatedAfter(
        emotionSection,
        "both dedicated classifiers share one link after the last applicable section"
      );
      assert
        .dom(".ai-feature-editor__model-change-warning")
        .doesNotExist("dedicated-only mode has no decision warning");
      await form().field("ai_sentiment_emotion_enabled").toggle();
      assertDedicatedAfter(
        sentimentSection,
        "sentiment-only dedicated guidance moves away from disabled emotion"
      );
      await form().field("ai_sentiment_enabled").toggle();
      assert
        .dom(".ai-feature-editor__dedicated-link")
        .doesNotExist("disabled classifiers have no dedicated guidance");
      assert
        .dom(".ai-feature-editor__decision-models-link")
        .doesNotExist("disabled classifiers have no decision guidance");
    });

    test("switches controls using draft dependencies and retains inactive configuration", async function (assert) {
      const settings = [
        SiteSetting.create({
          setting: "ai_sentiment_backfill_maximum_posts_per_hour",
          type: "integer",
          value: 2500,
          min: 0,
          max: 10000,
        }),
        SiteSetting.create({
          setting: "ai_sentiment_backfill_post_max_age_days",
          type: "integer",
          value: 60,
          min: 0,
        }),
      ];
      for (const type of ["sentiment", "emotion"]) {
        const enabled =
          type === "sentiment"
            ? "ai_sentiment_enabled"
            : "ai_sentiment_emotion_enabled";
        const strategy = `ai_sentiment_${type}_classification_strategy`;
        settings.push(
          SiteSetting.create({ setting: enabled, type: "bool", value: true }),
          SiteSetting.create({
            setting: strategy,
            type: "enum",
            value: "agent",
            valid_values: ["agent", "decision_model", "classification_model"],
            depends_on: [enabled],
            depends_behavior: "hidden",
          })
        );
        for (const backend of ["agent", "decision_model"]) {
          settings.push(
            SiteSetting.create({
              setting: `ai_sentiment_${type}_${backend}`,
              type: "enum",
              value: backend === "agent" ? "1" : "2",
              valid_values: ["1", "2", "3"],
              depends_on: [enabled, strategy],
              depends_on_values: { [strategy]: [backend] },
              depends_behavior: "hidden",
            })
          );
        }
      }
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );
      controller.settings = settings;
      const model = {
        module_name: "sentiment",
        feature_settings: settings,
        settingGroups: getSettingGroupsForFeature("sentiment"),
        formData: Object.fromEntries(
          settings.map((setting) => [setting.setting, setting.value])
        ),
      };
      await render(
        <template>
          <FeatureEditor @controller={{controller}} @model={{model}} />
        </template>
      );
      assert
        .dom('[data-name="ai_sentiment_backfill_maximum_posts_per_hour"] label')
        .includesText(
          "Posts per hour",
          "shows the background rate with a short label"
        );
      assert
        .dom('[data-name="ai_sentiment_backfill_post_max_age_days"] label')
        .includesText(
          "Post age limit (days)",
          "shows the age limit with a short label"
        );
      assert
        .dom('[data-name="ai_sentiment_backfill_post_max_age_days"] input')
        .hasAttribute(
          "min",
          "0",
          "allows today-only processing but not negative ages"
        );
      assert
        .dom(".ai-feature-editor__section-description")
        .hasText(
          i18n("discourse_ai.features.sentiment.background_description"),
          "explains scan timing, request costs, and retries once"
        );
      for (const type of ["sentiment", "emotion"]) {
        const field = `[data-name="ai_sentiment_${type}_classification_strategy"]`;
        assert
          .dom(`${field} label`)
          .includesText("Backend", "uses a concise backend label");
        for (const [value, label] of Object.entries({
          agent: "LLM agent",
          decision_model: "Decision model",
          classification_model: "Dedicated classification endpoint",
        })) {
          assert
            .dom(`${field} option[value="${value}"]`)
            .hasText(
              label,
              "translates the backend without changing its stored value"
            );
        }
      }
      assert
        .dom('[data-name="ai_sentiment_sentiment_agent"]')
        .exists("shows the selected agent backend");
      assert
        .dom('[data-name="ai_sentiment_sentiment_decision_model"]')
        .doesNotExist("hides the inactive decision selector");
      assert
        .dom(".ai-feature-editor__dedicated-link")
        .doesNotExist(
          "no endpoint link when neither capability uses dedicated"
        );
      await form().field("ai_sentiment_sentiment_agent").fillIn("3");
      await form()
        .field("ai_sentiment_sentiment_classification_strategy")
        .fillIn("decision_model");
      assert
        .dom('[data-name="ai_sentiment_sentiment_agent"]')
        .doesNotExist("immediately hides the agent selector");
      assert
        .dom('[data-name="ai_sentiment_sentiment_decision_model"]')
        .exists("immediately shows the decision selector before saving");
      assert
        .dom('[data-name="ai_sentiment_emotion_agent"]')
        .exists("does not change the independent emotion backend");
      assert
        .dom(".ai-feature-editor__decision-models-link")
        .exists("offers decision model management");
      await form()
        .field("ai_sentiment_emotion_classification_strategy")
        .fillIn("decision_model");
      assert
        .dom(".ai-feature-editor__model-change-warning")
        .exists(
          { count: 1 },
          "shows one model-change warning for both capabilities"
        );
      assert
        .dom('[data-name="ai_sentiment_emotion_decision_model"]')
        .includesText(
          i18n("discourse_ai.features.sentiment.emotion_scores"),
          "preserves the 28-emotion distribution note"
        );
      await form()
        .field("ai_sentiment_emotion_classification_strategy")
        .fillIn("classification_model");
      assert
        .dom(".ai-feature-editor__dedicated-link")
        .exists("either dedicated capability exposes endpoint configuration");
      assert
        .dom('[data-name="ai_sentiment_model_configs"]')
        .doesNotExist("never renders a masked JSON control");
      await form()
        .field("ai_sentiment_sentiment_classification_strategy")
        .fillIn("agent");
      assert
        .form()
        .field("ai_sentiment_sentiment_agent")
        .hasValue("3", "keeps the unsaved inactive agent selection");
      assert.strictEqual(
        controller.formApi.get("ai_sentiment_sentiment_decision_model"),
        "2",
        "keeps the inactive decision model"
      );
      assert.strictEqual(
        model.formData.ai_sentiment_sentiment_agent,
        "1",
        "does not mutate the saved form data"
      );
      controller.formApi.set(
        "ai_sentiment_emotion_classification_strategy",
        "agent"
      );
      await settled();
      assert
        .dom(".ai-feature-editor__dedicated-link")
        .doesNotExist("hides the endpoint link when no longer needed");

      await form().field("ai_sentiment_enabled").toggle();
      assert
        .dom('[data-name="ai_sentiment_sentiment_classification_strategy"]')
        .doesNotExist("disabling sentiment hides only its controls");
      assert
        .dom('[data-name="ai_sentiment_emotion_classification_strategy"]')
        .exists("emotion remains independently enabled");
      await form().field("ai_sentiment_emotion_enabled").toggle();
      assert
        .dom('[data-name="ai_sentiment_emotion_classification_strategy"]')
        .doesNotExist("both capabilities can be disabled");
      assert
        .dom('[data-name="ai_sentiment_backfill_maximum_posts_per_hour"]')
        .exists("processing limits remain configurable before enabling");
      await form().field("ai_sentiment_enabled").toggle();
      assert
        .form()
        .field("ai_sentiment_sentiment_agent")
        .hasValue("3", "re-enabling retains the selected agent");
      assert
        .dom('[data-name="ai_sentiment_emotion_agent"]')
        .doesNotExist("re-enabling sentiment leaves emotion off");
    });
  }
);
