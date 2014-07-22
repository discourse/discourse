Discourse.AdminBadgesRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Badge.findAll();
  },

  setupController: function(controller, model) {
    // TODO build into findAll
    Discourse.ajax('/admin/badges/groupings').then(function(json) {
      controller.set('badgeGroupings', json.badge_groupings);
    });
    Discourse.ajax('/admin/badges/types').then(function(json) {
      controller.set('badgeTypes', json.badge_types);
    });
    controller.set('model', model);
  }

});
