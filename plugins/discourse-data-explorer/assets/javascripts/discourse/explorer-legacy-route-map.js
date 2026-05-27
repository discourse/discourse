export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("explorer", function () {
      this.route("queries", function () {
        this.route("edit", { path: "/:query_id" });
      });
    });
  },
};
