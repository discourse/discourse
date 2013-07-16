/**
  Base route for showing private messages

  @class UserPrivateMessagesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_private_messages', {into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return this.modelFor('user');
  },

  setupController: function(controller, user) {
    var composerController = this.controllerFor('composer');
    controller.set('model', user);
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

/**
  Default private messages route

  @class UserPrivateMessagesIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').findStream(Discourse.UserAction.TYPES.messages_received);
  },

  setupController: function(controller, model) {
    this.controllerFor('userPrivateMessages').set('stream', model);
  }
});

/**
  Private messages sent route

  @class UserPrivateMessagesSentRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesSentRoute = Discourse.UserPrivateMessagesIndexRoute.extend({
  model: function() {
    return this.modelFor('user').findStream(Discourse.UserAction.TYPES.messages_sent);
  }
});

/**
  This controller handles actions related to a user's private messages.

  @class UserPrivateMessagesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesController = Discourse.ObjectController.extend({
  needs: ['composer'],

  composePrivateMessage: function() {
    this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  }

});
