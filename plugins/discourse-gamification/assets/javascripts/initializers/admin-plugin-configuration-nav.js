import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-gamification-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("discourse-gamification", [
        {
          label: "gamification.leaderboard.title",
          route: "adminPlugins.show.discourse-gamification-leaderboards",
        },
      ]);
    });
  },
};
