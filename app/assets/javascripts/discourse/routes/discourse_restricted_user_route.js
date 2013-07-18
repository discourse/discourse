/**
  A base route that allows us to redirect when access is restricted

  @class RestrictedUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.RestrictedUserRoute = Discourse.Route.extend({

  afterModel: function() {
    var user = this.modelFor('user');
    if (!user.get('can_edit')) {
      this.transitionTo('userActivity');
    }
  }

});


