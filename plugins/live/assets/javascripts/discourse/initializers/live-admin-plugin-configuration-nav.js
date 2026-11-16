import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "live";

export default {
  name: "live-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "microphone-lines");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "live.admin.dashboard_title",
          route: "adminPlugins.show.live-dashboard",
        },
        {
          label: "live.admin.rooms_title",
          route: "adminPlugins.show.live-rooms",
        },
        {
          label: "live.admin.recordings_title",
          route: "adminPlugins.show.live-recordings",
        },
      ]);
    });
  },
};
