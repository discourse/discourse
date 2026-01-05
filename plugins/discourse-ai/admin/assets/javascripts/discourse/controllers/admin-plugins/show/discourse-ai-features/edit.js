import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import { i18n } from "discourse-i18n";

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

  /**
   * Generates a FormKit validation string for a site setting.
   *
   * @param {Object} setting - The site setting object
   * @param {string} setting.type - The setting type (e.g., "integer", "bool", "string")
   * @param {number} [setting.min] - Minimum value for integer settings
   * @param {number} [setting.max] - Maximum value for integer settings
   * @returns {string|undefined} Validation string in FormKit format (e.g., "number|between:0,100")
   *                              or undefined if no validation is needed
   */
  @action
  getValidationFor(setting) {
    const validation = [];

    if (setting.type === "integer") {
      validation.push("number");

      if (setting.min !== undefined || setting.max !== undefined) {
        const min = setting.min ?? "";
        const max = setting.max ?? "";
        validation.push(`between:${min},${max}`);
      }
    }

    return validation.length > 0 ? validation.join("|") : undefined;
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
