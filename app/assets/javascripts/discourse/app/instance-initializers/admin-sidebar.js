import { withPluginApi } from "discourse/lib/plugin-api";
import getURL from "discourse-common/lib/get-url";

export default {
  initialize(owner) {
    this.site = owner.lookup("service:site");
    this.currentUser = owner.lookup("service:currentUser");

    if (!this.currentUser.staff) {
      return;
    }

    withPluginApi("1.8.0", (api) => {
      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AdminSidebarPanel extends BaseCustomSidebarPanel {
            key = "admin";
            switchButtonLabel = "BLAH";
            switchButtonIcon = "bolt";
            switchButtonDefaultUrl = getURL("/admin-revamp");
          }
      );

      api.setSidebarPanel("admin");

      api.setSeparatedSidebarMode();
      api.hideSidebarSwitchPanelButtons();
    });
  },
};
