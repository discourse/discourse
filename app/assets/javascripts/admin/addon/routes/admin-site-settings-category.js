import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminSiteSettingsCategoryRoute extends DiscourseRoute {
  @service router;

  model(params) {
    return this.modelFor("adminSiteSettings").filteredSettings.find(
      (setting) => setting.nameKey === params.category_id
    )?.siteSettings;
  }

  afterModel(model, transition) {
    if (
      (!model || model.length === 0) &&
      transition.to.params.category_id !== "all_results"
    ) {
      this.router.transitionTo("adminSiteSettingsCategory", "all_results");
    }
  }
}
