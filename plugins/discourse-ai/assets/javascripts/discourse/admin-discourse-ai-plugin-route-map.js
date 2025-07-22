export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-ai-personas", { path: "ai-personas" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });

    this.route("discourse-ai-llms", { path: "ai-llms" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });

    this.route("discourse-ai-tools", { path: "ai-tools" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });
    this.route("discourse-ai-spam", { path: "ai-spam" });
    this.route("discourse-ai-usage", { path: "ai-usage" });

    this.route(
      "discourse-ai-embeddings",
      { path: "ai-embeddings" },
      function () {
        this.route("new");
        this.route("edit", { path: "/:id/edit" });
      }
    );

    this.route("discourse-ai-features", { path: "ai-features" }, function () {
      this.route("edit", { path: "/:id/edit" });
    });
  },
};
