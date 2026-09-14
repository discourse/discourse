import { withPluginApi } from "discourse/lib/plugin-api";
import AskAiDashboard from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai";

export default {
  name: "ask-ai-dashboard",

  initialize() {
    withPluginApi((api) => {
      api.registerAdminDashboardSection("ask_ai", AskAiDashboard);
    });
  },
};
