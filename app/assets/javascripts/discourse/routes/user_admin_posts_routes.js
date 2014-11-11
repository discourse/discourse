function createAdminPostRoute (filter) {
  return Discourse.Route.extend({
    model: function () {
      return this.modelFor("user").get("postsStream");
    },

    afterModel: function () {
      return this.modelFor("user").get("postsStream").filterBy(filter);
    },

    setupController: function (controller, model) {
      controller.set("model", model);
      this.controllerFor("user").set("indexStream", true);
    },

    renderTemplate: function() {
      this.render("user/posts", { into: "user" });
    }
  });
}

Discourse.UserDeletedPostsRoute = createAdminPostRoute("deleted");
Discourse.UserFlaggedPostsRoute = createAdminPostRoute("flagged");
