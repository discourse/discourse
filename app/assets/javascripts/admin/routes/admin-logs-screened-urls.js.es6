import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  renderTemplate: function() {
    this.render("admin/templates/logs/screened-urls", { into: "adminLogs" });
  },

  setupController: function() {
    return this.controllerFor("adminLogsScreenedUrls").show();
  }
});
