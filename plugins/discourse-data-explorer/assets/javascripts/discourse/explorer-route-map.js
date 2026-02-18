export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("explorer", { path: "/" }, function () {
      this.route("queries", function () {
        this.route("details", { path: "/:query_id" });
      });
    });
  },
};
