export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route(
      "discourse-gamification-leaderboards",
      { path: "leaderboards" },
      function () {
        this.route("show", { path: "/:id" });
      }
    );
  },
};
