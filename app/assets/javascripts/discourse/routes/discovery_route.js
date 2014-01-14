/**
  The parent route for all discovery routes. Handles the logic for showing
  the loading spinners.

  @class DiscoveryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryRoute = Discourse.Route.extend({
  actions: {
    loading: function() {
      this.controllerFor('discovery').set('loading', true);
    },

    loadingComplete: function() {
      this.controllerFor('discovery').set('loading', false);
    },

    didTransition: function() {
      this.send('loadingComplete');
    }
  }
});

