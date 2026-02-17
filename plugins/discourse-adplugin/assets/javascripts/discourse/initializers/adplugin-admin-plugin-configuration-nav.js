import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-adplugin";

export default {
  name: "adplugin-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "rectangle-ad");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "admin.adplugin.house_ads.title",
          route: "adminPlugins.show.houseAds",
        },
      ]);
    });
  },
};
