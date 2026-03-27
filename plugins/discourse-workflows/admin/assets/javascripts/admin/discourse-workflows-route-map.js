export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-workflows", { path: "workflows" }, function () {
      this.route("new");
      this.route("show", { path: "/:id" }, function () {
        this.route("executions", function () {
          this.route("show", { path: "/:execution_id" });
        });
        this.route("settings");
      });
    });
    this.route("discourse-workflows-templates", { path: "templates" });
    this.route("discourse-workflows-variables", { path: "variables" });
    this.route("discourse-workflows-executions", { path: "executions" });
    this.route(
      "discourse-workflows-data-tables",
      { path: "data-tables" },
      function () {
        this.route("show", { path: "/:id" });
      }
    );
  },
};
