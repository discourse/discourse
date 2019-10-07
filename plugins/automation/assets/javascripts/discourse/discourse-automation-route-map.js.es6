export default {
  resource: "admin.adminPlugins",

  path: "/plugins",

  map() {
    this.route("discourse-automation", function() {
      this.route("workflows", function() {
        this.route("show", { path: "/:id" });
      });

      this.route("plans");
      this.route("plannables");
    });
  }
};
