import Draft from 'discourse/models/draft';

export default Discourse.Route.extend({

  renderTemplate() {
    this.render('user/messages');
  },


  model() {
    return this.modelFor("user");
  },

  setupController(controller, user) {
    this._super();
    // Bring up a draft
    const composerController = this.controllerFor("composer");
    controller.set("model", user);
    if (this.currentUser) {
      Draft.get("new_private_message").then(function(data) {
        if (data.draft) {
          composerController.open({
            draft: data.draft,
            draftKey: "new_private_message",
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence
          });
        }
      });
    }
  },

  actions: {
    willTransition: function() {
      this._super();
      this.controllerFor('user').set('pmView', null);
      return true;
    }
  }
});
