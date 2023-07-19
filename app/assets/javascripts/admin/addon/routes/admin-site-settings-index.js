/**
  Handles when you click the Site Settings tab in admin, but haven't
  chosen a category. It will redirect to the first category.
**/
import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminSiteSettingsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith(
      "adminSiteSettingsCategory",
      this.controllerFor("adminSiteSettings").get("visibleSiteSettings")[0]
        .nameKey
    );
  }
}
