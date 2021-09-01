import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PrivateMessageTopicTrackingState from "discourse/models/private-message-topic-tracking-state";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    const user = this.modelFor("user");
    return ajax(`/u/${user.username}/private-message-topic-tracking-state`)
      .then((pmTopicTrackingStateData) => {
        return {
          user,
          pmTopicTrackingStateData,
        };
      })
      .catch((e) => {
        popupAjaxError(e);
        return { user };
      });
  },

  setupController(controller, model) {
    const user = model.user;

    const pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
      messageBus: controller.messageBus,
      user,
    });

    pmTopicTrackingState.startTracking(model.pmTopicTrackingStateData);

    controller.setProperties({
      model: user,
      pmTopicTrackingState,
    });

    this.set("pmTopicTrackingState", pmTopicTrackingState);

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

  deactivate() {
    this.pmTopicTrackingState.stopTracking();
  },

  actions: {
    refresh() {
      this.refresh();
    },

    willTransition: function () {
      this._super(...arguments);
      this.controllerFor("user").set("pmView", null);
      return true;
    },
  },
});
