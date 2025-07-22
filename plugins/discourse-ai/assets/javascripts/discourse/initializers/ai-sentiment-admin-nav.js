import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  const currentUser = api.getCurrentUser();

  if (
    !currentUser ||
    !currentUser.admin ||
    !currentUser.can_see_sentiment_reports
  ) {
    return;
  }

  api.addAdminSidebarSectionLink("reports", {
    name: "sentiment_overview",
    route: "admin.dashboardSentiment",
    label: "discourse_ai.sentiments.sidebar.overview",
    icon: "chart-column",
  });
  api.addAdminSidebarSectionLink("reports", {
    name: "sentiment_analysis",
    route: "adminReports.show",
    routeModels: ["sentiment_analysis"],
    label: "discourse_ai.sentiments.sidebar.analysis",
    icon: "chart-pie",
  });
});
