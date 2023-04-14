import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    return this.modelFor("user");
  },

  afterModel() {
    return this.pmTopicTrackingState.startTracking();
  },

  setupController(controller, model) {
    controller.set("model", model);

    if (this.currentUser) {
      const composerController = this.controllerFor("composer");

      Draft.get("new_private_message").then((data) => {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence,
          });
        }
      });
    }
  },

  @action
  triggerRefresh() {
    this.refresh();
  },

  @action
  willTransition() {
    this._super(...arguments);
    return true;
  },
});
