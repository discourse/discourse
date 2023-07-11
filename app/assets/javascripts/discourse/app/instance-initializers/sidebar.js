import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";

export default {
  initialize() {
    withPluginApi("1.7.1", (api) => {
      api.addSidebarPanel((BaseCustomSidebarPanel) => {
        const MainSidebarPanel = class extends BaseCustomSidebarPanel {
          get key() {
            return "main";
          }
          get switchButtonLabel() {
            return I18n.t("sidebar.panels.forum.label");
          }

          get switchButtonIcon() {
            return "random";
          }

          get switchButtonDefaultUrl() {
            return "/";
          }
        };

        return MainSidebarPanel;
      });
    });
  },
};
