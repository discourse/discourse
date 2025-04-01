import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import SiteSetting from "admin/models/site-setting";

export default class AdminSiteSettingsRoute extends DiscourseRoute {
  @service dialog;
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

      await new Promise(() => {
        this.dialog.confirm({
          message: i18n("admin.site_settings.dirty_banner", {
            count: this.siteSettingChangeTracker.count,
          }),
          confirmButtonLabel: "admin.site_settings.save",
          cancelButtonLabel: "admin.site_settings.discard",
          didConfirm: () => {
            this.siteSettingChangeTracker.save();
            transition.retry();
          },
          didCancel: () => {
            this.siteSettingChangeTracker.discard();
            transition.retry();
          },
        });
      });
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
