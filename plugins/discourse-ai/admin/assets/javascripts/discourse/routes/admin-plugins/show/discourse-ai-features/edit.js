import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { getSettingGroupsForFeature } from "discourse/plugins/discourse-ai/discourse/lib/ai-feature-setting-groups";
import { dedicatedSettingsRoute } from "../../../../lib/ai-feature-settings-route.js";

export default class AdminPluginsShowDiscourseAiFeaturesEdit extends DiscourseRoute {
  @service router;

  async model(params) {
    const allFeatures = this.modelFor(
      "adminPlugins.show.discourse-ai-features"
    );
    const id = parseInt(params.id, 10);
    const currentFeature = allFeatures.find((feature) => feature.id === id);

    if (!currentFeature || dedicatedSettingsRoute(currentFeature.module_name)) {
      return currentFeature;
    }

    const { site_settings } = await ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: `ai-features/${currentFeature.module_name}`,
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

      // With a single option, offer it rather than an empty choice to fill in.
      if (
        setting.type === "enum" &&
        !value &&
        setting.valid_values?.length === 1
      ) {
        value = setting.valid_values[0].value;
      }

      currentFeature.formData[setting.setting] = value;
    });

    return currentFeature;
  }

  redirect(model) {
    if (!model) {
      this.router.replaceWith("adminPlugins.show.discourse-ai-features");
    } else {
      const dedicatedRoute = dedicatedSettingsRoute(model.module_name);
      if (dedicatedRoute) {
        this.router.replaceWith(dedicatedRoute);
      }
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);

    controller.set("settings", model.feature_settings);
  }
}
