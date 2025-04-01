import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigWithSettingsRoute extends DiscourseRoute {
  @service dialog;
  @service siteSettingChangeTracker;

  _transitionConfirmed = true;

  resetController(controller, isExiting) {
    // Have to do this because this is the parent route. We don't want to have
    // to make a controller for every single settings route when we can reset
    // the filter here.
    const settingsController = this.controllerFor(
      `${this.fullRouteName}.settings`
    );
    if (isExiting) {
      settingsController.set("filter", "");
    }
  }

  @action
  async willTransition(transition) {
    if (this.siteSettingChangeTracker.hasUnsavedChanges) {
      transition.abort();

      await new Promise(() => {
        this.dialog.confirm({
          message: i18n("admin.site_settings.dirty_banner", {
            count: this.siteSettingChangeTracker.count,
          }),
          confirmButtonLabel: "admin.site_settings.save",
          cancelButtonLabel: "admin.site_settings.discard",
          didConfirm: async () => {
            await this.siteSettingChangeTracker.save();
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
}
