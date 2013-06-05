/**
  This route displays a user's private messages.

  @class UserPrivateMessagesRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesRoute = Discourse.RestrictedUserRoute.extend({

  model: function() {
    return this.modelFor('user').findStream(Discourse.UserAction.GOT_PRIVATE_MESSAGE);
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, stream) {
    var composerController = this.controllerFor('composer');
    controller.set('model', stream);
    Discourse.Draft.get('new_private_message').then(function(data) {
      if (data.draft) {
        composerController.open({
          draft: data.draft,
          draftKey: 'new_private_message',
          ignoreIfChanged: true,
          draftSequence: data.draft_sequence
        });
      }
    });
  }


});


