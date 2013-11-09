/**
  The base route for showing an activity stream.

  @class UserActivityStreamRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityStreamRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('user').get('stream');
  },

  afterModel: function() {
    return this.modelFor('user').get('stream').filterBy(this.get('userActionType'));
  },

  renderTemplate: function() {
    this.render('user_stream', {into: 'user', outlet: 'userOutlet'});
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('user_activity').set('userActionType', this.get('userActionType'));

    this.controllerFor('user').set('indexStream', !this.get('userActionType'));
  }
});

// Build all activity stream routes
['bookmarks', 'edits', 'likes_given', 'likes_received', 'replies', 'posts', 'index'].forEach(function (userAction) {
  Discourse["UserActivity" + userAction.classify() + "Route"] = Discourse.UserActivityStreamRoute.extend({
    userActionType: Discourse.UserAction.TYPES[userAction]
  });
});