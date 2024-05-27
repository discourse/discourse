export default {
  resource: "admin.adminPlugins",

  path: "/plugins",

  map() {
    this.route(
      "discourse-automation",

      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
  },
};
