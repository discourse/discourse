export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("live-dashboard");
    this.route("live-recordings");
    this.route(
      "live-rooms",

      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
  },
};
