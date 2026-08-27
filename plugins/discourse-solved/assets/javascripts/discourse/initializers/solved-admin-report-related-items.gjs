import { withPluginApi } from "discourse/lib/plugin-api";
import SolvedAdminReportRelatedItems from "discourse/plugins/discourse-solved/discourse/components/solved-admin-report-related-items";
import SolvedAdminReportTableSummary from "discourse/plugins/discourse-solved/discourse/components/solved-admin-report-table-summary";

export default {
  name: "solved-admin-report-related-items",

  initialize() {
    withPluginApi((api) => {
      api.registerAdminReportRelatedItemsRenderer("accepted_solutions", {
        relatedItemsComponent: SolvedAdminReportRelatedItems,
        tableSummaryComponent: SolvedAdminReportTableSummary,
      });
    });
  },
};
