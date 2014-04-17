/**
  Shows a list of all badges.

  @class BadgesIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.BadgesIndexRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.Badge.findAll();
  }
});
