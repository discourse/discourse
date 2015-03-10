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
    showDetailsModal(logRecord) {
      showModal('admin_staff_action_log_details', logRecord);
      this.controllerFor('modal').set('modalClass', 'log-details-modal');
    },

    showCustomDetailsModal(logRecord) {
      showModal(logRecord.action_name + '_details', logRecord);
      this.controllerFor('modal').set('modalClass', 'tabbed-modal log-details-modal');
    }
  }
});
