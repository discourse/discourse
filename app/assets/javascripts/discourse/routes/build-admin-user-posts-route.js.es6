import ShowFooter from "discourse/mixins/show-footer";

export default function (filter) {
  return Discourse.Route.extend(ShowFooter, {
    actions: {
      didTransition: function() {
        this.controllerFor('user').set('indexStream', true);
        this.controllerFor("user-posts")._showFooter();
        return true;
      }
    },

    model: function () {
      return this.modelFor("user").get("postsStream");
    },

    afterModel: function () {
      return this.modelFor("user").get("postsStream").filterBy(filter);
    },

    setupController: function(controller, model) {
      // initialize "canLoadMore"
      model.set("canLoadMore", model.get("itemsLoaded") === 60);

      this.controllerFor("user-posts").set("model", model);
    },

    renderTemplate: function() {
      this.render("user/posts", { into: "user" });
    }
  });
}
