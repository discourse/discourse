import DiscourseRoute from "discourse/routes/discourse";
import CustomReaction from "../models/discourse-reactions-custom-reaction";

export default class UserNotificationsReactionsReceived extends DiscourseRoute {
  templateName = "user-activity-reactions";
  controllerName = "user-activity-reactions";

  queryParams = {
    acting_username: { refreshModel: true },
    include_likes: { refreshModel: true },
  };

  model(params) {
    return CustomReaction.findReactions(
      "reactions-received",
      this.modelFor("user").get("username"),
      {
        actingUsername: params.acting_username,
        includeLikes: params.include_likes,
      }
    );
  }

  setupController(controller, model) {
    let loadedAll = model.length < 20;
    this.controllerFor("user-activity-reactions").setProperties({
      model,
      canLoadMore: !loadedAll,
      reactionsUrl: "reactions-received",
      username: this.modelFor("user").get("username"),
      actingUsername: controller.acting_username,
      includeLikes: controller.include_likes,
    });
    this.controllerFor("application").set("showFooter", loadedAll);
  }
}
