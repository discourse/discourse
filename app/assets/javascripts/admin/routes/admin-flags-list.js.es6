import showModal from 'discourse/lib/show-modal';
import FlaggedPost from 'admin/models/flagged-post';

export default Discourse.Route.extend({
  model(params) {
    this.filter = params.filter;
    return FlaggedPost.findAll(params.filter);
  },

  setupController(controller, model) {
    controller.set('model', model);
    controller.set('query', this.filter);
  },

  actions: {
    showAgreeFlagModal(model) {
      showModal('admin-agree-flag', { model, admin: true });
      this.controllerFor('modal').set('modalClass', 'agree-flag-modal');
    },

    showDeleteFlagModal(model) {
      showModal('admin-delete-flag', { model, admin: true });
      this.controllerFor('modal').set('modalClass', 'delete-flag-modal');
    }

  }
});
