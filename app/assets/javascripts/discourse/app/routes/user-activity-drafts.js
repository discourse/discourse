import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  model() {
    const user = this.modelFor("user");
    const draftsStream = user.get("userDraftsStream");
    draftsStream.reset();

    return draftsStream.findItems(this.site).then(() => {
      return {
        stream: draftsStream,
        isAnotherUsersPage: this.isAnotherUsersPage(user),
        emptyState: this.emptyState(),
      };
    });
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  emptyState() {
    const title = I18n.t("user_activity.no_drafts_title");
    const body = I18n.t("user_activity.no_drafts_body");
    return { title, body };
  },

  activate() {
    this.appEvents.on("draft:destroyed", this, this.refresh);
  },

  deactivate() {
    this.appEvents.off("draft:destroyed", this, this.refresh);
  },

  @action
  didTransition() {
    this.controllerFor("user-activity")._showFooter();
    return true;
  },
});
