import I18n from "I18n";
import { addSidebarPanel } from "discourse/lib/sidebar/custom-sections";

export default {
  initialize() {
    addSidebarPanel((BaseCustomSidebarPanel) => {
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
  },
};
