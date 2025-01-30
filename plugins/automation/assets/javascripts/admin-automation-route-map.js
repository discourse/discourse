export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins/automation",

  map() {
    this.route("automation", { path: "/" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id" });
    });
  },
};
