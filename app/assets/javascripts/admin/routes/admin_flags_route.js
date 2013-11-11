/**
  Handles routes related to viewing flags.

  @class AdminFlagsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/

Discourse.AdminFlagsRoute = Discourse.Route.extend({
  redirect: function() {
    this.transitionTo('adminFlags.active');
  }
});
