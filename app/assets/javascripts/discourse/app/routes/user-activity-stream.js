import ViewingActionType from "discourse/mixins/viewing-action-type";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class UserActivityStream extends DiscourseRoute.extend(
  ViewingActionType
) {
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
    this.viewingActionType(this.userActionType);
  }

  emptyState() {
    const title = I18n.t("user_activity.no_activity_title");
    const body = "";
    return { title, body };
  }
}
