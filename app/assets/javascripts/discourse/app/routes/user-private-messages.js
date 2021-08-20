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
      .then((response) => {
        return {
          user: user,
          pmTopicTrackingState: response,
        };
      })
      .catch(popupAjaxError);
  },

  setupController(controller, model) {
    const user = model.user;

    controller.setProperties({
      model: user,
      pmTopicTrackingState: PrivateMessageTopicTrackingState.create({
        data: model.pmTopicTrackingState,
        messageBus: controller.messageBus,
        user: user,
      }),
    });

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
