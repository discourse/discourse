export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("explorer", { path: "queries" }, function () {
      this.route("details", { path: "/:query_id" });
    });
  },
};
