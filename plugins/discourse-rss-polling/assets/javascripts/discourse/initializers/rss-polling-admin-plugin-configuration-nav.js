import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-rss-polling";

export default {
  name: "rss-polling-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "rss");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "admin.rss_polling.feeds.title",
          route: "adminPlugins.show.discourse-rss-polling-feeds",
          description: "admin.rss_polling.feeds.nav_description",
        },
      ]);
    });
  },
};
