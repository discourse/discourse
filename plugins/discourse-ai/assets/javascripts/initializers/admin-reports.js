import { withPluginApi } from "discourse/lib/plugin-api";
import AdminReportEmotion from "discourse/plugins/discourse-ai/discourse/components/admin-report-emotion";

export default {
  name: "discourse-ai-admin-reports",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    // We need to import dynamically with CommonJS require because
    // using ESM import in an initializer would cause the component to be imported globally
    // and cause errors for non-admin users since the component is only available to admins
    const AdminReportSentimentAnalysis =
      require("discourse/plugins/discourse-ai/discourse/components/admin-report-sentiment-analysis").default;

    withPluginApi((api) => {
      api.registerReportModeComponent("emotion", AdminReportEmotion);
      api.registerReportModeComponent(
        "sentiment_analysis",
        AdminReportSentimentAnalysis
      );

      api.registerValueTransformer(
        "admin-reports-show-query-params",
        ({ value }) => {
          return [...value, "selectedChart"];
        }
      );
    });
  },
};
