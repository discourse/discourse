import { withPluginApi } from "discourse/lib/plugin-api";
import SolvedAdminReportRelatedItems from "discourse/plugins/discourse-solved/discourse/components/solved-admin-report-related-items";
import SolvedAdminReportTableSummaryItem from "discourse/plugins/discourse-solved/discourse/components/solved-admin-report-table-summary-item";

export default {
  name: "solved-admin-report-related-items",

  initialize() {
    withPluginApi((api) => {
      api.registerAdminReportRelatedItemsRenderer("accepted_solutions", {
        relatedItemsComponent: SolvedAdminReportRelatedItems,
        tableSummary: {
          itemComponent: SolvedAdminReportTableSummaryItem,
          itemsKey: "solved_topics",
          titleKey:
            "admin.reports.related_items.table_summary.solved_topics_title",
        },
      });
    });
  },
};
