import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Unit | Controller | admin-plugins/show/discourse-ai-features/edit",
  function (hooks) {
    setupTest(hooks);

    test("saving skips a dependent field hidden by a draft parent change", async function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );
      sinon.stub(this.owner.lookup("service:router"), "refresh");
      const saved = [];
      pretender.put("/admin/site_settings/:name", (request) => {
        saved.push(request.params.name);
        return response({});
      });
      controller.settings = [
        { setting: "enabled", value: true },
        {
          setting: "dependent",
          value: "old",
          depends_on: ["enabled"],
          depends_behavior: "hidden",
        },
      ];
      await controller.save({ enabled: false, dependent: "stale draft" });
      assert.deepEqual(saved, ["enabled"], "the hidden draft is not submitted");
    });

    test("findSetting returns correct setting by name", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      controller.settings = [
        { setting: "setting_one", value: "value1" },
        { setting: "setting_two", value: "value2" },
        { setting: "setting_three", value: "value3" },
      ];

      const result = controller.findSetting("setting_two");

      assert.deepEqual(
        result,
        { setting: "setting_two", value: "value2" },
        "should return the correct setting"
      );
    });

    test("findSetting returns undefined for non-existent setting", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );

      controller.settings = [{ setting: "setting_one", value: "value1" }];

      const result = controller.findSetting("nonexistent");

      assert.strictEqual(
        result,
        undefined,
        "should return undefined for non-existent setting"
      );
    });
    test("uses concise sentiment labels and help without changing other settings", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );
      const definition = {
        label: "Original label",
        description: "Original description",
        valid_values: [
          "agent",
          { value: "decision_model", name: "Original choice" },
        ],
      };
      const labels = {
        ai_sentiment_enabled: "Enabled",
        ai_sentiment_sentiment_classification_strategy: "Backend",
        ai_sentiment_sentiment_agent: "Agent",
        ai_sentiment_sentiment_decision_model: "Decision model",
        ai_sentiment_emotion_classification_strategy: "Backend",
        ai_sentiment_emotion_agent: "Agent",
        ai_sentiment_emotion_decision_model: "Decision model",
        ai_sentiment_backfill_maximum_posts_per_hour: "Posts per hour",
        ai_sentiment_backfill_post_max_age_days: "Post age limit (days)",
      };

      for (const [setting, label] of Object.entries(labels)) {
        assert.strictEqual(
          controller.settingDefinition({ setting, definition }).label,
          label,
          `${setting} uses a short label`
        );
      }
      for (const setting of [
        "ai_sentiment_sentiment_classification_strategy",
        "ai_sentiment_emotion_classification_strategy",
        "ai_sentiment_sentiment_agent",
        "ai_sentiment_emotion_agent",
        "ai_sentiment_sentiment_decision_model",
      ]) {
        assert.strictEqual(
          controller.settingDefinition({ setting, definition }).description,
          undefined,
          `${setting} omits redundant help`
        );
      }
      assert.strictEqual(
        controller.settingDefinition({
          setting: "ai_sentiment_emotion_decision_model",
          definition,
        }).description,
        i18n("discourse_ai.features.sentiment.emotion_scores"),
        "retains the emotion distribution explanation"
      );
      assert.strictEqual(
        controller.settingDefinition({ setting: "ai_bot_enabled", definition }),
        definition,
        "leaves unrelated settings untouched"
      );
      assert.strictEqual(
        definition.description,
        "Original description",
        "preserves descriptions for the core settings editor"
      );
    });

    test("hidden dependencies use draft boolean and enum values", function (assert) {
      const controller = this.owner.lookup(
        "controller:admin-plugins/show/discourse-ai-features/edit"
      );
      controller.settings = [
        { setting: "enabled", value: true },
        { setting: "scope", value: "public" },
      ];
      const setting = {
        depends_behavior: "hidden",
        depends_on: ["enabled", "scope"],
        depends_on_values: { scope: ["include", "exclude"] },
      };
      assert.true(
        controller.isSettingVisible(setting, {
          enabled: true,
          scope: "include",
        }),
        "unsaved enum selection reveals a dependent field"
      );
      assert.false(
        controller.isSettingVisible(setting, {
          enabled: "false",
          scope: "include",
        }),
        "string false does not satisfy a boolean dependency"
      );
      assert.false(
        controller.isSettingVisible(setting, {
          enabled: true,
          scope: "public",
        }),
        "all parent dependencies must match"
      );
      assert.true(
        controller.isSettingVisible(
          { ...setting, depends_on: ["missing"] },
          {}
        ),
        "parents outside the area do not hide settings"
      );
      assert.true(
        controller.isSettingVisible(
          { ...setting, depends_behavior: undefined },
          {}
        ),
        "non-hidden settings retain their visibility"
      );
      assert.false(
        controller.isSettingVisible(undefined, {}),
        "missing settings are not rendered"
      );
    });
  }
);
