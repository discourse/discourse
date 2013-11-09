/**
  If we request /user/eviltrout without a sub route.

  @class UserIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserIndexRoute = Discourse.UserActivityRoute.extend({
  redirect: function() {
    this.transitionTo('userActivity', this.modelFor('user'));
  }
});
