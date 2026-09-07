export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("voice-dashboard");
    this.route("voice-recordings");
    this.route(
      "voice-rooms",

      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
  },
};
