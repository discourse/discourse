/**
  The base route for showing an activity stream.

  @class UserActivityRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_activity', {into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return this.modelFor('user');
  },

  setupController: function(controller, user) {
    this.controllerFor('userActivity').set('model', user);

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

Discourse.UserActivityIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').findStream(this.get('userActionType'));
  },

  renderTemplate: function() {
    this.render('user_stream', {into: 'user_activity', outlet: 'activity'});
  },

  setupController: function() {
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));
  }
});

Discourse.UserIndexRoute = Discourse.UserActivityRoute.extend({
  renderTemplate: function() {
    this._super();
    this.render('user_stream', {into: 'user_activity', outlet: 'activity'});
  },

  model: function() {
    return this.modelFor('user').findStream();
  },

  setupController: function(controller, model) {
    this.controllerFor('userActivity').set('model', this.modelFor('user'));
    this.set('model', model);
  }
});

// Build all the filter routes
Object.keys(Discourse.UserAction.TYPES).forEach(function (userAction) {
  Discourse["UserActivity" + userAction.classify() + "Route"] = Discourse.UserActivityIndexRoute.extend({
    userActionType: Discourse.UserAction.TYPES[userAction]
  });
});

// // Build the private message routes
Discourse.UserPrivateMessagesRoute = Discourse.UserActivityRoute.extend({});
Discourse.UserPrivateMessagesIndexRoute = Discourse.UserActivityMessagesReceivedRoute;
Discourse.UserPrivateMessagesSentRoute = Discourse.UserActivityMessagesSentRoute;

/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.ObjectController.extend({
  needs: ['composer'],

  privateMessageView: function() {
    return (this.get('userActionType') === Discourse.UserAction.TYPES.messages_sent) ||
           (this.get('userActionType') === Discourse.UserAction.TYPES.messages_received);
  }.property('userActionType'),

  composePrivateMessage: function() {
    return this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      usernames: this.get('model.username'),
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  }
});
