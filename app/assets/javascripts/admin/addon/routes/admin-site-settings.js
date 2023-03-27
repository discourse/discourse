import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import SiteSetting from "admin/models/site-setting";

export default class AdminSiteSettingsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  model() {
    return SiteSetting.findAll();
  }

  afterModel(siteSettings) {
    const controller = this.controllerFor("adminSiteSettings");

    if (!controller.get("visibleSiteSettings")) {
      controller.set("visibleSiteSettings", siteSettings);
    }
  }

  @action
  refreshAll() {
    SiteSetting.findAll().then((settings) => {
      this.controllerFor("adminSiteSettings").set("model", settings);
    });
  }
}
