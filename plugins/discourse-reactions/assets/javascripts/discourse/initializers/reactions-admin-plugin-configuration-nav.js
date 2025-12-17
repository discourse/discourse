import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-reactions-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-reactions", "discourse-emojis");
    });
  },
};
