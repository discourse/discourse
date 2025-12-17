import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-assign-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("discourse-assign", [], "user-plus");
    });
  },
};
