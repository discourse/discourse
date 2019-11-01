import EmberObject from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
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
      name: I18n.t("admin.site_settings.categories." + params.category_id),
      siteSettings: this.controllerFor("adminSiteSettingsCategory").get(
        "filteredContent"
      )
    });
  }
});
