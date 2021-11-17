import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("admin/templates/logs/screened-emails", { into: "adminLogs" });
  },

  setupController() {
    return this.controllerFor("adminLogsScreenedEmails").show();
  },
});
