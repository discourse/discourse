export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("chat-integration", function () {
      this.route("provider", { path: "/:provider" });
    });
  },
};
