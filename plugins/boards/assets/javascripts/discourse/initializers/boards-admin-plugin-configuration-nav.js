import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "boards";

export default {
  name: "boards-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "boards");
    });
  },
};
