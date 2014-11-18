export default Discourse.Route.extend({
  model: function(params) {
    this.filter = params.filter;
    return Discourse.FlaggedPost.findAll(params.filter);
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('query', this.filter);
  },

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
