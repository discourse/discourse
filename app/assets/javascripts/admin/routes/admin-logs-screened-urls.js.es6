export default Discourse.Route.extend({
  renderTemplate: function() {
    this.render("admin/templates/logs/screened-urls", { into: "adminLogs" });
  },

  setupController: function() {
    return this.controllerFor("adminLogsScreenedUrls").show();
  }
});
