import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";
import Composer from "discourse/models/composer";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    return this.modelFor("user");
  },

  setupController(controller, user) {
    const composerController = this.controllerFor("composer");
    controller.set("model", user);
    if (this.currentUser) {
      Draft.get("new_private_message").then(data => {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence
          });
        }
      });
    }
  },

  actions: {
    willTransition: function() {
      this._super(...arguments);
      this.controllerFor("user").set("pmView", null);
      return true;
    }
  }
});
