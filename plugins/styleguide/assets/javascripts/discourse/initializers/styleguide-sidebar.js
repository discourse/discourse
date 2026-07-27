import { withPluginApi } from "discourse/lib/plugin-api";
import styleguideSidebarPanelBuilder from "../lib/styleguide-sidebar-panel";

export default {
  name: "styleguide-sidebar",

  initialize(container) {
    // Nothing else injects the service, and the route reaches it through the container rather
    // than at module scope, so it has to be built here or the panel registers against nothing.
    container.lookup("service:styleguide-sidebar");

    withPluginApi((api) => {
      api.addSidebarPanel(styleguideSidebarPanelBuilder);
    });
  },
};
