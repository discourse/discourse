export default Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/logs/screened_ip_addresses', {into: 'adminLogs'});
  },

  setupController: function() {
    return this.controllerFor('adminLogsScreenedIpAddresses').show();
  }
});
