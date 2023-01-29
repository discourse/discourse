import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  setupController() {
    return this.controllerFor("adminLogsScreenedIpAddresses").show();
  },
});
