/**
  Handles routes related to users.

  @class UserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserRoute = Discourse.Route.extend({

  model: function(params) {
    return Discourse.User.create({username: params.username}).loadDetails();
  },

  serialize: function(params) {
    return { username: Em.get(params, 'username').toLowerCase() };
  }

});
