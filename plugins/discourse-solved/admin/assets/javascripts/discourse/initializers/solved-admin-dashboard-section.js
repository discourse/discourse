import { withPluginApi } from "discourse/lib/plugin-api";
import SupportSection from "discourse/plugins/discourse-solved/admin/components/dashboard/support";

export default {
  name: "solved-admin-dashboard-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.solved_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerAdminDashboardSection("support", SupportSection);
    });
  },
};
