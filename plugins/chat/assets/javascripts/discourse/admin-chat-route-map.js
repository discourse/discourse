export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route(
      "discourse-chat-incoming-webhooks",
      { path: "hooks" },
      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
  },
};
