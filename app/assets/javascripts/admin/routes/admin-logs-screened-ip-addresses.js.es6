export default Discourse.Route.extend({
  renderTemplate() {
    this.render("admin/templates/logs/screened-ip-addresses", {
      into: "adminLogs"
    });
  },

  setupController() {
    return this.controllerFor("adminLogsScreenedIpAddresses").show();
  }
});
