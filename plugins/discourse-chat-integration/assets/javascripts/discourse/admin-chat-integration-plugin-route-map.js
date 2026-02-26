export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route(
      "discourse-chat-integration-providers",
      { path: "providers" },
      function () {
        this.route("show", { path: "/:provider" });
      }
    );
  },
};
