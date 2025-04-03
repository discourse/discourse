import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import SiteSetting from "admin/models/site-setting";

export default class AdminSiteSettingsRoute extends DiscourseRoute {
  @service siteSettingChangeTracker;

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
  async willTransition(transition) {
    if (
      this.siteSettingChangeTracker.hasUnsavedChanges &&
      transition.from.name !== transition.to.name
    ) {
      transition.abort();

      await this.siteSettingChangeTracker.confirmTransition();

      transition.retry();
    }
  }

  @action
  refreshAll() {
    SiteSetting.findAll().then((settings) => {
      this.controllerFor("adminSiteSettings").set("model", settings);
    });
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("filter", "");
    }
  }
}
