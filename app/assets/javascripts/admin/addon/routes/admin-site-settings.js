import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import SiteSetting from "admin/models/site-setting";

export default class AdminSiteSettingsRoute extends DiscourseRoute {
  @service siteSettingChangeTracker;

  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return i18n("admin.config.site_settings.title");
  }

  async model() {
    return await SiteSetting.findAll();
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
