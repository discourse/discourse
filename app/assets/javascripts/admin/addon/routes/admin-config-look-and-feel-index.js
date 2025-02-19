import { service } from "@ember/service";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminConfigLookAndFeelIndexRoute extends AdminConfigWithSettingsRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminConfig.lookAndFeel.themes");
  }
}
