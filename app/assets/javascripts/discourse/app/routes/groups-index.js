import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default class GroupsIndexRoute extends DiscourseRoute {
  queryParams = {
    order: { refreshModel: true, replace: true },
    asc: { refreshModel: true, replace: true },
    filter: { refreshModel: true },
    type: { refreshModel: true, replace: true },
    username: { refreshModel: true },
  };

  titleToken() {
    return I18n.t("groups.index.title");
  }

  model(params) {
    return params;
  }

  setupController(controller, params) {
    controller.loadGroups(params);
  }
}
