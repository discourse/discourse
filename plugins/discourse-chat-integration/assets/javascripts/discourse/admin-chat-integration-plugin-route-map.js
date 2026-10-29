export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route(
      "discourse-chat-integration-providers",
      { path: "providers" },
      function () {
        this.route("new");
        this.route("edit", { path: "/:provider" });
      }
    );
  },
};
