/**
  The base Application route

  @class ApplicationRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Discourse.Route.extend({
  setupController: function(controller) {
    Discourse.set('currentUser', Discourse.User.current());
  }
});
