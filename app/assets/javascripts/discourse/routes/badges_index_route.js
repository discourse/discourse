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
      return Discourse.Badge.findAll({onlyListable: true});
    }
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    Discourse.set('title', I18n.t('badges.title'));
  }
});
