/**
  Handles when you click the Site Settings tab in admin, but haven't
  chosen a category. It will redirect to the first category.
**/
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminSiteSettingsIndexRoute extends DiscourseRoute {
  @service router;
  @service currentUser;

  beforeModel() {
    if (!this.currentUser.use_admin_sidebar) {
      this.router.replaceWith(
        "adminSiteSettingsCategory",
        this.controllerFor("adminSiteSettings").get("visibleSiteSettings")[0]
          .nameKey
      );
    }
  }
}
