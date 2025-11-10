import { action } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export function buildGroupPage(type) {
  return class GroupActivityPosts extends DiscourseRoute {
    type = type;
    templateName = "group.activity.posts";
    controllerName = "group.activity.posts";

    titleToken() {
      return i18n(`groups.${type}`);
    }

    async model(params, transition) {
      const categoryId = transition.to.queryParams.category_id;
      const posts = await this.modelFor("group").findPosts({
        type,
        categoryId,
      });

      return new TrackedArray(posts);
    }

    setupController(controller, model) {
      let loadedAll = model.length < 20;
      controller.setProperties({
        model,
        type,
        canLoadMore: !loadedAll,
      });
    }

    @action
    didTransition() {
      return true;
    }
  };
}

export default buildGroupPage("posts");
