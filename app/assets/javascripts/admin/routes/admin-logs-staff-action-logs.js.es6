import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend({
  // TODO: make this automatic using an `{{outlet}}`
  renderTemplate: function() {
    this.render('admin/templates/logs/staff-action-logs', {into: 'adminLogs'});
  },

  actions: {
    showDetailsModal(model) {
      showModal('admin-staff-action-log-details', { model, admin: true });
      this.controllerFor('modal').set('modalClass', 'log-details-modal');
    },

    showCustomDetailsModal(model) {
      const modalName = (model.action_name + '_details').replace(/\_/g, "-");

      showModal(modalName, {
        model,
        admin: true,
        templateName: 'site-customization-change'
      });
      this.controllerFor('modal').set('modalClass', 'tabbed-modal log-details-modal');
    }
  }
});
