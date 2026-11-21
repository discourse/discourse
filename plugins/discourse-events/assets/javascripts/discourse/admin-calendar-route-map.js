export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route(
      "discourse-events-registration-forms",
      { path: "registration-forms" },
      function () {
        this.route("new");
        this.route("edit", { path: ":id/edit" });
      }
    );
    this.route("discourse-events-submissions", { path: "submissions" });
    this.route("discourse-events-holidays", { path: "holidays" });
  },
};
