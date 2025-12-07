import { withPluginApi } from "discourse/lib/plugin-api";
import { optionalRequire } from "discourse/lib/utilities";
import AdminReportEmotion from "../components/admin-report-emotion";

const AdminReportSentimentAnalysis = optionalRequire(
  "discourse/plugins/discourse-ai/discourse/components/admin-report-sentiment-analysis"
);

export default {
  name: "discourse-ai-admin-reports",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.staff) {
      return;
    }

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
