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

/**
  A route for showing a user's activity

  @class UserIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').findStream();
  },

  setupController: function(controller, model) {
    this.controllerFor('userActivity').setProperties({
      model: this.modelFor('user'),
      stream: model,
      privateMessageView: this.get('privateMessageRoute')
    });
  }
});

// Build all the filter routes
Object.keys(Discourse.UserAction.TYPES).forEach(function (userAction) {
  Discourse["UserActivity" + userAction.classify() + "Route"] = Discourse.UserActivityIndexRoute.extend({
    model: function() {
      return this.modelFor('user').findStream(Discourse.UserAction.TYPES[userAction]);
    }
  });
});


/**
  Show the user's default route

  @class UserIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserIndexRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_activity', {into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    var user = this.modelFor('user');
    return user.findStream();
  },

  setupController: function(controller, stream) {
    var userActivity = this.controllerFor('userActivity');
    userActivity.setProperties({
      model: this.modelFor('user'),
      stream: stream
    });
  }
});

/**
  Base route for showing private messages

  @class UserPrivateMessagesRoute
  @extends Discourse.UserActivityRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesRoute = Discourse.UserActivityRoute.extend({});

/**
  Default private messages route

  @class UserPrivateMessagesIndexRoute
  @extends Discourse.UserActivityIndexRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesIndexRoute = Discourse.UserActivityIndexRoute.extend({
  privateMessageRoute: true,

  model: function() {
    return this.modelFor('user').findStream(Discourse.UserAction.TYPES.messages_received);
  }
});

/**
  Private messages sent route

  @class UserPrivateMessagesSentRoute
  @extends Discourse.UserActivityIndexRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesSentRoute = Discourse.UserActivityIndexRoute.extend({
  privateMessageRoute: true,

  model: function() {
    return this.modelFor('user').findStream(Discourse.UserAction.TYPES.messages_sent);
  }
});


/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.ObjectController.extend({
  needs: ['composer'],

  kickOffPrivateMessage: (function() {
    if (this.get('content.openPrivateMessage')) {
      this.composePrivateMessage();
    }
  }).observes('content.openPrivateMessage'),

  composePrivateMessage: function() {
    return this.get('controllers.composer').open({
      action: Discourse.Composer.PRIVATE_MESSAGE,
      usernames: this.get('model.username'),
      archetypeId: 'private_message',
      draftKey: 'new_private_message'
    });
  }
});
