import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSetting, {
  isSettingValueTrue,
} from "discourse/admin/models/site-setting";
import { i18n } from "discourse-i18n";

const SENTIMENT_SETTING_LABELS = {
  ai_sentiment_enabled: "enabled",
  ai_sentiment_emotion_enabled: "enabled",
  ai_sentiment_sentiment_classification_strategy: "backend",
  ai_sentiment_sentiment_agent: "agent",
  ai_sentiment_sentiment_decision_model: "decision_model",
  ai_sentiment_emotion_classification_strategy: "backend",
  ai_sentiment_emotion_agent: "agent",
  ai_sentiment_emotion_decision_model: "decision_model",
  ai_sentiment_backfill_maximum_posts_per_hour: "posts_per_hour",
  ai_sentiment_backfill_post_max_age_days: "post_age_limit",
};

export default class AdminPluginsShowDiscourseAiFeaturesEditController extends Controller {
  @service toasts;
  @service router;

  @tracked settings = [];

  @action
  onRegisterFormApi(api) {
    this.formApi = api;
  }

  @action
  findSetting(settingName) {
    return this.settings.find((s) => s.setting === settingName);
  }

  @action
  settingDefinition(setting) {
    const labelKey = SENTIMENT_SETTING_LABELS[setting.setting];
    if (!labelKey) {
      return setting.definition;
    }

    const definition = {
      ...setting.definition,
      label: i18n(`discourse_ai.features.sentiment.${labelKey}`),
    };

    switch (labelKey) {
      case "backend":
        definition.description = undefined;
        definition.valid_values = definition.valid_values.map((choice) => {
          const value = typeof choice === "object" ? choice.value : choice;
          return {
            value,
            name: i18n(`discourse_ai.features.backends.${value}`),
          };
        });
        break;
      case "agent":
        definition.description = undefined;
        break;
      case "decision_model":
        definition.description =
          setting.setting === "ai_sentiment_emotion_decision_model"
            ? i18n("discourse_ai.features.sentiment.emotion_scores")
            : undefined;
        break;
      case "posts_per_hour":
        definition.description = i18n(
          "discourse_ai.features.sentiment.posts_per_hour_description"
        );
        break;
    }

    return definition;
  }

  @action
  sentimentBackendGroup(data, backend) {
    return [
      ["emotion", "ai_sentiment_emotion_enabled"],
      ["sentiment", "ai_sentiment_enabled"],
    ].find(
      ([type, setting]) =>
        isSettingValueTrue(data[setting]) &&
        data[`ai_sentiment_${type}_classification_strategy`] === backend
    )?.[0];
  }

  @action
  isSettingVisible(setting, data) {
    if (!setting) {
      return false;
    }
    if (setting.depends_behavior !== "hidden") {
      return true;
    }

    return (setting.depends_on || []).every((name) => {
      const parent = this.findSetting(name);
      if (!parent) {
        return true;
      }
      const value = Object.hasOwn(data, name) ? data[name] : parent.value;
      const allowedValues = setting.depends_on_values?.[name];
      return allowedValues
        ? allowedValues.map(String).includes(String(value))
        : isSettingValueTrue(value);
    });
  }

  @action
  async save(data) {
    if (this.formApi) {
      this.formApi.removeErrors();
    }

    const errors = {};

    for (const [key, value] of Object.entries(data)) {
      const setting = this.findSetting(key);
      if (!setting) {
        continue;
      }

      const valuesEqual = this.valuesEqual(setting.value, value);

      if (valuesEqual) {
        continue;
      }

      try {
        await SiteSetting.update(key, value);
        setting.value = value;
      } catch (e) {
        const errorMsg = e.jqXHR?.responseJSON?.errors?.[0] || "Unknown error";
        errors[key] = errorMsg;

        if (this.formApi) {
          this.formApi.addError(key, {
            title: setting.humanized_name,
            message: errorMsg,
          });
        }
      }
    }

    if (Object.keys(errors).length === 0) {
      this.toasts.success({
        data: { message: i18n("saved") },
        duration: 2000,
      });

      this.router.refresh("adminPlugins.show.discourse-ai-features");
    } else {
      this.toasts.error({
        data: {
          message: i18n("discourse_ai.features.settings_save_error"),
        },
        duration: 4000,
      });
    }
  }

  valuesEqual(a, b) {
    if (a === b) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.toString() === b.toString();
  }
}
