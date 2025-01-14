import { setTopicList } from "discourse/lib/topic-list-tracker";
import DiscourseRoute from "discourse/routes/discourse";

export const QUERY_PARAMS = {
  ascending: { replace: true, refreshModel: true, default: false },
  order: { replace: true, refreshModel: true },
};

export default class UserTopicsListRoute extends DiscourseRoute {
  templateName = "user-topics-list";
  controllerName = "user-topics-list";
  queryParams = QUERY_PARAMS;

  setupController(controller, model) {
    setTopicList(model);

    const userActionType = this.userActionType;
    this.controllerFor("user").set("userActionType", userActionType);
    this.controllerFor("user-activity").set("userActionType", userActionType);
    controller.setProperties({
      model,
      hideCategory: false,
    });
  }
}
