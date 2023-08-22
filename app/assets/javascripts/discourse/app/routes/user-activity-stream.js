import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import I18n from "I18n";

export default DiscourseRoute.extend(ViewingActionType, {
  templateName: "user/stream",

  queryParams: {
    acting_username: { refreshModel: true },
  },

  model() {
    const user = this.modelFor("user");
    const stream = user.get("stream");

    return {
      stream,
      emptyState: this.emptyState(),
    };
  },

  afterModel(model, transition) {
    return model.stream.filterBy({
      filter: this.userActionType,
      actingUsername: transition.to.queryParams.acting_username,
    });
  },

  setupController() {
    this._super(...arguments);
    this.viewingActionType(this.userActionType);
  },

  emptyState() {
    const title = I18n.t("user_activity.no_activity_title");
    const body = "";
    return { title, body };
  },
});
