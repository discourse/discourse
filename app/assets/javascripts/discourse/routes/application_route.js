/**
  The base Application route

  @class ApplicationRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ApplicationRoute = Discourse.Route.extend({
  setupController: function(controller) {
    //Discourse.set('site', Discourse.Site.instance());
    var currentUser = PreloadStore.get('currentUser');
    if (currentUser) {
      Discourse.set('currentUser', Discourse.User.create(currentUser));
    }
    // make sure we delete preloaded data
    PreloadStore.remove('currentUser');
  }
});
