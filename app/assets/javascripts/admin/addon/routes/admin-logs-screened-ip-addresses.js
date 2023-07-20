import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsScreenedIpAddressesRoute extends DiscourseRoute {
  setupController() {
    return this.controllerFor("adminLogsScreenedIpAddresses").show();
  }
}
