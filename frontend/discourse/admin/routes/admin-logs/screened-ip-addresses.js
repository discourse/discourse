import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsScreenedIpAddressesRoute extends DiscourseRoute {
  @service currentUser;

  beforeModel() {
    if (!this.currentUser.can_see_ip) {
      this.transitionTo("adminLogs.staffActionLogs");
    }
  }

  setupController() {
    return this.controllerFor("adminLogs.screenedIpAddresses").show();
  }
}
