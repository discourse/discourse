import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-openid-connect";

export default {
  name: "openid-connect-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "id-card");
    });
  },
};
