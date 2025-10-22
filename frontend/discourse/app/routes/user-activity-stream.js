import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivityStream extends DiscourseRoute {
  templateName = "user/stream";

  queryParams = {
    acting_username: { refreshModel: true },
  };

  model() {
    const user = this.modelFor("user");
    const stream = user.get("stream");

    return {
      stream,
      emptyState: this.emptyState(),
    };
  }

  afterModel(model, transition) {
    return model.stream.filterBy({
      filter: this.userActionType,
      actingUsername: transition.to.queryParams.acting_username,
    });
  }

  setupController() {
    super.setupController(...arguments);
    this.controllerFor("user-activity").userActionType = this.userActionType;
  }

  emptyState() {
    const title = i18n("user_activity.no_activity_title");
    const body = "";
    return { title, body };
  }
}
