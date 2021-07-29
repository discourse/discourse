import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    return this.modelFor("user");
  },

  setupController(controller, user) {
    controller.set("model", user);

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
