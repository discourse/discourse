export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-rss-polling-feeds", { path: "feeds" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });
  },
};
