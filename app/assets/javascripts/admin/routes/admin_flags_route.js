Discourse.AdminFlagsIndexRoute = Discourse.Route.extend({
  redirect: function() {
    this.transitionTo('adminFlags.active');
  }
});

Discourse.AdminFlagsRouteType = Discourse.Route.extend({
  model: function() {
    return Discourse.FlaggedPost.findAll(this.get('filter'));
  },

  setupController: function(controller, model) {
    var adminFlagsController = this.controllerFor('adminFlags');
    adminFlagsController.set('content', model);
    adminFlagsController.set('query', this.get('filter'));
  },

});

Discourse.AdminFlagsActiveRoute = Discourse.AdminFlagsRouteType.extend({
  filter: 'active',

  actions: {

    showAgreeFlagModal: function (flaggedPost) {
      Discourse.Route.showModal(this, 'admin_agree_flag', flaggedPost);
      this.controllerFor('modal').set('modalClass', 'agree-flag-modal');
    },

    showDeleteFlagModal: function (flaggedPost) {
      Discourse.Route.showModal(this, 'admin_delete_flag', flaggedPost);
      this.controllerFor('modal').set('modalClass', 'delete-flag-modal');
    }

  }
});


Discourse.AdminFlagsOldRoute = Discourse.AdminFlagsRouteType.extend({
  filter: 'old'
});
