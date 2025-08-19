import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

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
        item.set("titleHtml", emojiUnescape(escapeExpression(item.title)));
      }
    });
  }
}
