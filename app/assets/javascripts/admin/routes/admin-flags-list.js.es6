import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend({
  model(params) {
    this.filter = params.filter;
    return Discourse.FlaggedPost.findAll(params.filter);
  },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('query', this.filter);
  },

  actions: {
    showAgreeFlagModal(flaggedPost) {
      showModal('modals/admin-agree-flag', flaggedPost);
      this.controllerFor('modal').set('modalClass', 'agree-flag-modal');
    },

    showDeleteFlagModal(flaggedPost) {
      showModal('modals/admin-delete-flag', flaggedPost);
      this.controllerFor('modal').set('modalClass', 'delete-flag-modal');
    }

  }
});
