import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-topic-voting";

export default {
  name: "topic-voting-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "check-to-slot");
    });
  },
};
