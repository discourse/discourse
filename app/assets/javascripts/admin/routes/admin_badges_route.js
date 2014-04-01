Discourse.AdminBadgesRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Badge.findAll();
  },

  setupController: function(controller, model) {
    Discourse.ajax('/admin/badges/types').then(function(json) {
      controller.set('badgeTypes', json.badge_types);
    });
    controller.set('model', model);
  }

});
