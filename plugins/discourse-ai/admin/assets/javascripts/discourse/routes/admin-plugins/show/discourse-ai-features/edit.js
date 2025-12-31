import SiteSetting from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { getSettingGroupsForFeature } from "discourse/plugins/discourse-ai/discourse/lib/ai-feature-setting-groups";

export default class AdminPluginsShowDiscourseAiFeaturesEdit extends DiscourseRoute {
  async model(params) {
    const allFeatures = this.modelFor(
      "adminPlugins.show.discourse-ai-features"
    );
    const id = parseInt(params.id, 10);
    const currentFeature = allFeatures.find((feature) => feature.id === id);

    const { site_settings } = await ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: `ai-features/${currentFeature.module_name}`,
        plugin: "discourse-ai",
        category: "discourse_ai",
      },
    });

    currentFeature.feature_settings = site_settings.map((setting) =>
      SiteSetting.create(setting)
    );

    currentFeature.settingGroups = getSettingGroupsForFeature(
      currentFeature.module_name
    );

    currentFeature.formData = {};
    currentFeature.feature_settings.forEach((setting) => {
      let value = setting.value;

      if (setting.type === "bool") {
        value = value === "true" || value === true;
      }

      if (setting.type === "enum" && typeof value === "string") {
        const numValue = parseInt(value, 10);
        if (!isNaN(numValue) && numValue.toString() === value) {
          value = numValue;
        }
      }

      currentFeature.formData[setting.setting] = value;
    });

    return currentFeature;
  }

  setupController(controller, model) {
    super.setupController(controller, model);

    controller.set("settings", model.feature_settings);
  }
}
