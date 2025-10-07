import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminConfigLoginPluginTabRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.config.login.title");
  }

  resetController(controller, isExiting) {
    // Need to override here to reset the parent settings filter too
    const settingsController = this.controllerFor("adminConfig.login.settings");
    if (isExiting) {
      settingsController.set("filter", "");
      controller.set("filter", "");
    }
  }
}
