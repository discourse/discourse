import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend({
  // TODO: make this automatic using an `{{outlet}}`
  renderTemplate: function() {
    this.render('admin/templates/logs/staff_action_logs', {into: 'adminLogs'});
  },

  setupController: function(controller) {
    controller.resetFilters();
    controller.refresh();
  },

  actions: {
    showDetailsModal(model) {
      showModal('modals/admin-staff-action-log-details', { model });
      this.controllerFor('modal').set('modalClass', 'log-details-modal');
    },

    showCustomDetailsModal(model) {
      const modalName = "modals/" + (model.action_name + '_details').replace("_", "-");
      showModal(modalName, { model });
      this.controllerFor('modal').set('modalClass', 'tabbed-modal log-details-modal');
    }
  }
});
