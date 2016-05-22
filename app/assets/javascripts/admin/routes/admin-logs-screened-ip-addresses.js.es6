export default Discourse.Route.extend({
  renderTemplate() {
    this.render('admin/templates/logs/screened_ip_addresses', {into: 'adminLogs'});
  },

  setupController() {
    return this.controllerFor('adminLogsScreenedIpAddresses').show();
  }
});
