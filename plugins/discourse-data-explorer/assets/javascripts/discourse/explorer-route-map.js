export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("explorer", function () {
      this.route("queries", function () {
        this.route("details", { path: "/:query_id" });
      });
    });
  },
};
