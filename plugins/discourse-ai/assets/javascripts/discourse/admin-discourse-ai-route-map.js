export default {
  resource: "admin.dashboard",
  path: "/dashboard",
  map() {
    this.route("admin.dashboardSentiment", {
      path: "/dashboard/sentiment",
      resetNamespace: true,
    });
  },
};
