import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-microsoft-auth-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav(
        "discourse-microsoft-auth",
        [],
        "fab-microsoft"
      );
    });
  },
};
