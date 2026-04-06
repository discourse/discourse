import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "solved-user-options",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.solved_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addSaveableUserOption("notify_on_solved", {
        page: "notifications",
      });
    });
  },
};
