import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  renderTemplate() {
    this.render("admin/templates/logs/screened-ip-addresses", {
      into: "adminLogs"
    });
  },

  setupController() {
    return this.controllerFor("adminLogsScreenedIpAddresses").show();
  }
});
