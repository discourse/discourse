import Controller from "@ember/controller";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class AdminConfigLoginController extends Controller {
  @service router;

  get currentTabLabel() {
    const routeName = this.router.currentRouteName;

    if (routeName === "adminConfig.login.authenticators") {
      return i18n("admin.config.login.sub_pages.authenticators.title");
    }

    if (routeName === "adminConfig.login.discourseconnect") {
      return i18n("admin.config.login.sub_pages.discourseconnect.title");
    }

    if (routeName === "adminConfig.login.plugin-tab") {
      const pluginTab = this.router.currentRoute?.params?.wildcard;

      if (pluginTab) {
        return i18n(`admin.config.login.sub_pages.${pluginTab}`);
      }
    }

    return null;
  }
}
