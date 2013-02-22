/**
  A base route that allows us to redirect when access is restricted

  @class RestrictedUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.RestrictedUserRoute = Discourse.Route.extend({

  enter: function(router, context) {
    var user = this.controllerFor('user').get('content');
    this.allowed = user.can_edit;
  },

  redirect: function() {
    if (!this.allowed) {
      return this.transitionTo('user.activity');
    }
  }

});


