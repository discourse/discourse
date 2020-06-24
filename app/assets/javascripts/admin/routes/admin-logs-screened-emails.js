import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  renderTemplate: function() {
    this.render("admin/templates/logs/screened-emails", { into: "adminLogs" });
  },

  setupController: function() {
    return this.controllerFor("adminLogsScreenedEmails").show();
  }
});
