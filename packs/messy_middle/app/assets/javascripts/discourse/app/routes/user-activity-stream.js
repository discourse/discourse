import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";
import { action } from "@ember/object";
import I18n from "I18n";

export default DiscourseRoute.extend(ViewingActionType, {
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
    if (!this.isPoppedState(transition)) {
      this.session.set("userStreamScrollPosition", null);
    }

    return model.stream.filterBy({
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
