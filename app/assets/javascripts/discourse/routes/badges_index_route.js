/**
  Shows a list of all badges.

  @class BadgesIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.BadgesIndexRoute = Discourse.Route.extend({
  model: function() {
    if (PreloadStore.get('badges')) {
      return PreloadStore.getAndRemove('badges').then(function(json) {
        return Discourse.Badge.createFromJson(json);
      });
    } else {
      return Discourse.Badge.findAll();
    }
  }
});
