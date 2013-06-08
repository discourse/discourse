/**
  A base route that allows us to redirect when access is restricted

  @class RestrictedUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.RestrictedUserRoute = Discourse.Route.extend({

  redirect: function(user) {
    if (!user.get('can_edit')) {
      this.transitionTo('user.activity', user);
    }
  }

});


