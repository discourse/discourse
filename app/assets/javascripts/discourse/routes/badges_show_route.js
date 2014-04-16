/**
  Shows a particular badge.

  @class BadgesShowRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.BadgesShowRoute = Ember.Route.extend({
  serialize: function(model) {
    return {id: model.get('id'), slug: model.get('name').replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase()};
  },

  model: function(params) {
    return Discourse.Badge.findById(params.id);
  },

  setupController: function(controller, model) {
    Discourse.UserBadge.findByBadgeId(model.get('id')).then(function(userBadges) {
      controller.set('userBadges', userBadges);
    });
    controller.set('model', model);
  }
});
