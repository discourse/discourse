export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route(
      "discourse-gamification-leaderboards",
      { path: "leaderboards" },
      function () {
        this.route("new");
        this.route("edit", { path: "/:id/edit" });
        this.route("show", { path: "/:id" });
      }
    );
  },
};
