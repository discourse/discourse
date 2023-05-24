import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { setTopicList } from "discourse/lib/topic-list-tracker";

export default DiscourseRoute.extend(ViewingActionType, {
  templateName: "user-topics-list",
  controllerName: "user-topics-list",

  setupController(controller, model) {
    setTopicList(model);

    const userActionType = this.userActionType;
    this.controllerFor("user").set("userActionType", userActionType);
    this.controllerFor("user-activity").set("userActionType", userActionType);
    controller.setProperties({
      model,
      hideCategory: false,
    });
  },
});
