import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import SiteSetting from "admin/models/site-setting";

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

    return currentFeature;
  }

  @action
  willTransition() {
    // site settings may amend if a feature is enabled or disabled, so refresh the model
    // even on back button
    this.router.refresh("adminPlugins.show.discourse-ai-features");
  }
}
