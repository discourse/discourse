import { withPluginApi } from "discourse/lib/plugin-api";
import styleguideSidebarPanelBuilder from "../lib/styleguide-sidebar-panel.js";

export default {
  name: "styleguide-sidebar",

  initialize() {
    withPluginApi((api) => {
      api.addSidebarPanel(styleguideSidebarPanelBuilder);
    });
  },
};
