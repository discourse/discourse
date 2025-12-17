import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "policy-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-policy", "file-signature");
    });
  },
};
