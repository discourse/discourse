/**
  The base route for showing a user's activity

  @class UserActivityRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityRoute = Discourse.Route.extend({

  model: function() {
    return this.modelFor('user');
  },

  setupController: function(controller, user) {

    this.controllerFor('userActivity').set('model', user);
    this.controllerFor('user').set('pmView', null);

    // Bring up a draft
    var composerController = this.controllerFor('composer');
    controller.set('model', user);
    if (Discourse.User.current()) {
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
  }

});

Discourse.UserPrivateMessagesRoute = Discourse.UserActivityRoute.extend({});