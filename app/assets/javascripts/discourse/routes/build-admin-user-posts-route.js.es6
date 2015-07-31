export default function (filter) {
  return Discourse.Route.extend({
    actions: {
      didTransition() {
        this.controllerFor("user").set("indexStream", true);
        this.controllerFor("user-posts")._showFooter();
        return true;
      }
    },

    model() {
      return this.modelFor("user").get("postsStream");
    },

    afterModel() {
      return this.modelFor("user").get("postsStream").filterBy(filter);
    },

    setupController(controller, model) {
      // initialize "canLoadMore"
      model.set("canLoadMore", model.get("itemsLoaded") === 60);

      this.controllerFor("user-posts").set("model", model);
    },

    renderTemplate() {
      this.render("user/posts", { into: "user" });
    }
  });
}
