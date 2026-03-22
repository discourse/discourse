export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-workflows", { path: "/" }, function () {
      this.route("variables");
      this.route("executions");
      this.route("data-tables", function () {
        this.route("show", { path: "/:id" });
      });
      this.route("new");
      this.route("show", { path: "/:id" }, function () {
        this.route("executions", function () {
          this.route("show", { path: "/:execution_id" });
        });
        this.route("settings");
      });
    });
  },
};
