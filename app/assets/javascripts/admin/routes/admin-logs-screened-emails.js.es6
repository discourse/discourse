export default Discourse.Route.extend({
  renderTemplate: function() {
    this.render("admin/templates/logs/screened-emails", { into: "adminLogs" });
  },

  setupController: function() {
    return this.controllerFor("adminLogsScreenedEmails").show();
  }
});
