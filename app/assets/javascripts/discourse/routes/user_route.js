/**
  Handles routes related to users.

  @class UserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserRoute = Discourse.Route.extend({

  model: function(params) {
    return Discourse.User.create({username: params.username});
  },

  serialize: function(params) {
    if (!params) return {};
    return { username: Em.get(params, 'username').toLowerCase() };
  },

  setupController: function(controller, user) {
    user.findDetails();
    controller.set('model', user);

    // Add a search context
    this.controllerFor('search').set('searchContext', user.get('searchContext'));
  },

  activate: function() {
    this._super();
    var user = this.modelFor('user');
    Discourse.MessageBus.subscribe("/users/" + user.get('username_lower'), function(data) {
      user.loadUserAction(data);
    });
  },

  deactivate: function() {
    this._super();
    Discourse.MessageBus.unsubscribe("/users/" + this.modelFor('user').get('username_lower'));

    // Remove the search context
    this.controllerFor('search').set('searchContext', null);
  }


});
