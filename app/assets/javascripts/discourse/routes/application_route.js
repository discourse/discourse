/**
  The base Application route

  @class ApplicationRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Discourse.Route.extend({
  setupController: function(controller) {
    var currentUser;
    Discourse.set('site', Discourse.Site.create(PreloadStore.getStatic('site')));
    currentUser = PreloadStore.getStatic('currentUser');
    if (currentUser) {
      Discourse.set('currentUser', Discourse.User.create(currentUser));
    }
  }
});


