import { get } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";

export function buildGroupPage(type) {
  return DiscourseRoute.extend({
    type,

    titleToken() {
      return I18n.t(`groups.${type}`);
    },

    model(params, transition) {
      let categoryId = get(transition.to, "queryParams.category_id");
      return this.modelFor("group").findPosts({ type, categoryId });
    },

    setupController(controller, model) {
      let loadedAll = model.length < 20;
      this.controllerFor("group-activity-posts").setProperties({
        model,
        type,
        canLoadMore: !loadedAll
      });
      this.controllerFor("application").set("showFooter", loadedAll);
    },

    renderTemplate() {
      this.render("group-activity-posts");
    },

    actions: {
      didTransition() {
        return true;
      }
    }
  });
}

export default buildGroupPage("posts");
