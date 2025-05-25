export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route(
      "automation",
      { path: "automations" },

      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
  },
};
