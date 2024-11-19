import { action, get } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export function buildGroupPage(type) {
  return class GroupActivityPosts extends DiscourseRoute {
    type = type;
    templateName = "group-activity-posts";
    controllerName = "group-activity-posts";

    titleToken() {
      return i18n(`groups.${type}`);
    }

    model(params, transition) {
      let categoryId = get(transition.to, "queryParams.category_id");
      return this.modelFor("group").findPosts({ type, categoryId });
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
