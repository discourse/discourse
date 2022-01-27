import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("admin/templates/logs/screened-urls", { into: "adminLogs" });
  },

  setupController() {
    return this.controllerFor("adminLogsScreenedUrls").show();
  },
});
