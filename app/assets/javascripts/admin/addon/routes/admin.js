import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { MAIN_PANEL } from "discourse/services/sidebar-state";
import I18n from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate() {
    this.controllerFor("application").set("showTop", true);
    this.sidebarState.setPanel(MAIN_PANEL);
  }
}
