import { emojiUnescape } from "discourse/lib/text";

export default function(filter) {
  return Discourse.Route.extend({
    actions: {
      didTransition() {
        this.controllerFor("user").set("indexStream", true);
        this.controllerFor("user-posts")._showFooter();
        return true;
      }
    },

    model() {
      return this.modelFor("user").postsStream;
    },

    afterModel(model) {
      return model.filterBy({ filter });
    },

    setupController(controller, model) {
      // initialize "canLoadMore"
      model.set("canLoadMore", model.itemsLoaded === 60);

      model.content.forEach(item => {
        if (item.title) {
          item.set(
            "title",
            emojiUnescape(Handlebars.Utils.escapeExpression(item.title))
          );
        }
      });

      this.controllerFor("user-posts").set("model", model);
    },

    renderTemplate() {
      this.render("user/posts", { into: "user" });
    }
  });
}
