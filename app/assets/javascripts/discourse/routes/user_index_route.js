/**
  If we request /users/eviltrout without a sub route.

  @class UserIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserIndexRoute = Discourse.UserActivityRoute.extend({
  redirect: function() {
    this.replaceWith('userActivity', this.modelFor('user'));
  }
});
