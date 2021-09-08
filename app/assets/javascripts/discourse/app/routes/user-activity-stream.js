import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { action } from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend(ViewingActionType, {
  queryParams: {
    acting_username: { refreshModel: true },
  },

  emptyStateOthers: I18n.t("user_activity.no_activity_others"),

  model() {
    const user = this.modelFor("user");
    const streamModel = user.get("stream");

    streamModel.set("isAnotherUsersPage", this.isAnotherUsersPage(user));
    streamModel.set("emptyState", this.emptyState());
    streamModel.set("emptyStateOthers", this.emptyStateOthers);

    return streamModel;
  },

  afterModel(model, transition) {
    return model.filterBy({
      filter: this.userActionType,
      actingUsername: transition.to.queryParams.acting_username,
    });
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
    this.viewingActionType(this.userActionType);
  },

  emptyState() {
    const title = I18n.t("user_activity.no_activity_title");
    const body = "";
    return { title, body };
  },

  @action
  didTransition() {
    this.controllerFor("user-activity")._showFooter();
    return true;
  },
});
