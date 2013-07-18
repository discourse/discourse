Discourse.UserActivityRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('user_activity', {into: 'user', outlet: 'userOutlet' });
  },

  model: function() {
    return this.modelFor('user');
  }
});

Discourse.UserActivityIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').findStream();
  },

  setupController: function(controller, model) {
    this.controllerFor('userActivity').set('stream', model);
  }
});

Object.keys(Discourse.UserAction.TYPES).forEach(function (userAction) {
  Discourse["UserActivity" + userAction.classify() + "Route"] = Discourse.UserActivityIndexRoute.extend({
    model: function() {
      return this.modelFor('user').findStream(Discourse.UserAction.TYPES[userAction]);
    }
  });
});

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
      stream: stream,
      model: this.modelFor('user')
    });
  }
});

/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.Controller.extend({
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
