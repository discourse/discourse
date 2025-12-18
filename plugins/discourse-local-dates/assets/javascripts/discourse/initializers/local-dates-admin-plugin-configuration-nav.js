import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-local-dates";

export default {
  name: "local-dates-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "far-clock");
    });
  },
};
