import DiscourseRoute from "discourse/routes/discourse";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { action } from "@ember/object";

export default class UserDeletedPosts extends DiscourseRoute {
  templateName = "user/posts";
  controllerName = "user-posts";

  model() {
    return this.modelFor("user").postsStream;
  }

  afterModel(model) {
    return model.filterBy({ filter: "deleted" });
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    model.set("canLoadMore", model.itemsLoaded === 60);

    model.content.forEach((item) => {
      if (item.title) {
        item.set("title", emojiUnescape(escapeExpression(item.title)));
      }
    });
  }

  @action
  didTransition() {
    this.controller._showFooter();
    return true;
  }
}
