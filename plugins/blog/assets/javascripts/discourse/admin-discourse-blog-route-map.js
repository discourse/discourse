export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("discourse-blog-appearance", { path: "appearance" });
    this.route("discourse-blog-identity", { path: "identity" });
    this.route("discourse-blog-blogs", { path: "blogs" }, function () {
      this.route("new");
      this.route("edit", { path: "/:blog_id" }, function () {
        this.route("about");
        this.route("settings");
        this.route("theme");
      });
    });
    this.route("discourse-blog-themes", { path: "themes" }, function () {
      this.route("new");
      this.route("import", { path: "import/new" });
      this.route("edit", { path: "/:id/edit" });
    });
  },
};
