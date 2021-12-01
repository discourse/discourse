import DiscourseRoute from "discourse/routes/discourse";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { action } from "@ember/object";

export default function (filter) {
  return DiscourseRoute.extend({
    @action
    didTransition() {
      this.controllerFor("user-posts")._showFooter();
      return true;
    },

    model() {
      return this.modelFor("user").get("postsStream");
    },

    afterModel(model) {
      return model.filterBy({ filter });
    },

    setupController(controller, model) {
      // initialize "canLoadMore"
      model.set("canLoadMore", model.get("itemsLoaded") === 60);

      model.get("content").forEach((item) => {
        if (item.get("title")) {
          item.set("title", emojiUnescape(escapeExpression(item.title)));
        }
      });

      this.controllerFor("user-posts").set("model", model);
    },

    renderTemplate() {
      this.render("user/posts", { into: "user" });
    },
  });
}
