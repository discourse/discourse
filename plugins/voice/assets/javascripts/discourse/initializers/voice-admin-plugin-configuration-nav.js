import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "voice";

export default {
  name: "voice-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "microphone-lines");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "voice.admin.dashboard_title",
          route: "adminPlugins.show.voice-dashboard",
        },
        {
          label: "voice.admin.rooms_title",
          route: "adminPlugins.show.voice-rooms",
        },
        {
          label: "voice.admin.recordings_title",
          route: "adminPlugins.show.voice-recordings",
        },
      ]);
    });
  },
};
