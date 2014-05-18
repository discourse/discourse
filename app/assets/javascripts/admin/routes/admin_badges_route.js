Discourse.AdminBadgesRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Badge.findAll().then(function(badges) {
      return badges.filter(function(badge) {
        return badge.id >= 100;
      });
    });
  },

  setupController: function(controller, model) {
    Discourse.ajax('/admin/badges/types').then(function(json) {
      controller.set('badgeTypes', json.badge_types);
    });
    controller.set('model', model);
  }

});
