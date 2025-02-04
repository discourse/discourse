import EmberObject from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminSiteSettingsCategoryRoute extends DiscourseRoute {
  model(params) {
    // The model depends on user input, so let the controller do the work:
    this.controllerFor("adminSiteSettingsCategory").set(
      "categoryNameKey",
      params.category_id
    );
    this.controllerFor("adminSiteSettings").set(
      "categoryNameKey",
      params.category_id
    );
    return EmberObject.create({
      nameKey: params.category_id,
      name: i18n("admin.site_settings.categories." + params.category_id),
      siteSettings: this.controllerFor("adminSiteSettingsCategory").get(
        "filteredContent"
      ),
    });
  }
}
