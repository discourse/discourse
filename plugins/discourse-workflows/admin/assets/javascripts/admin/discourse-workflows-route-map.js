export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  bundleName: "workflows-admin",

  map() {
    this.route("discourse-workflows", { path: "workflows" }, function () {
      this.route("new");
      this.route("show", { path: "/:id" }, function () {
        this.route("node", { path: "/nodes/:node_id" });
        this.route("executions", function () {
          this.route("show", { path: "/:execution_id" });
        });
        this.route("settings", function () {
          this.route("fields", function () {
            this.route("new");
            this.route("edit", { path: "/:setting_field_id/edit" });
          });
        });
        this.route("versions");
      });
    });
    this.route("discourse-workflows-templates", { path: "templates" });
    this.route("discourse-workflows-variables", { path: "variables" });
    this.route("discourse-workflows-credentials", { path: "credentials" });
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
