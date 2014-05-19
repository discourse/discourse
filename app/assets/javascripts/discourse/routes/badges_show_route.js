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
    if (PreloadStore.get('badge')) {
      return PreloadStore.getAndRemove('badge').then(function(json) {
        return Discourse.Badge.createFromJson(json);
      });
    } else {
      return Discourse.Badge.findById(params.id);
    }
  },

  setupController: function(controller, model) {
    Discourse.UserBadge.findByBadgeId(model.get('id')).then(function(userBadges) {
      controller.set('userBadges', userBadges);
      controller.set('userBadgesLoaded', true);
    });
    controller.set('model', model);
    Discourse.set('title', model.get('displayName'));
  },

  actions: {
    loadMore: function() {
      var self = this;
      Discourse.UserBadge.findByBadgeId(this.currentModel.get('id'), {
        granted_before: this.get('controller.minGrantedAt') / 1000
      }).then(function(userBadges) {
        self.get('controller.userBadges').pushObjects(userBadges);
      });
    }
  }
});
