/**
  Shows a list of all badges.

  @class BadgesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.BadgesRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.Badge.findAll();
  }
});
