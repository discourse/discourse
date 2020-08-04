import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("groups.index.title");
  },

  queryParams: {
    order: { refreshModel: true, replace: true },
    asc: { refreshModel: true, replace: true },
    filter: { refreshModel: true },
    type: { refreshModel: true, replace: true },
    username: { refreshModel: true }
  },

  model(params) {
    return params;
  },

  setupController(controller, params) {
    controller.loadGroups(params);
  }
});
