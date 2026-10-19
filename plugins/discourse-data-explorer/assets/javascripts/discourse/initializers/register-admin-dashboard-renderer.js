import { withPluginApi } from "discourse/lib/plugin-api";
import DataExplorerAdminDashboardCard from "../components/admin-dashboard-card.gjs";

export default {
  name: "data-explorer-register-admin-dashboard-renderer",
  initialize() {
    withPluginApi((api) => {
      api.registerAdminDashboardReportRenderer(
        "data_explorer_query",
        DataExplorerAdminDashboardCard
      );
    });
  },
};
