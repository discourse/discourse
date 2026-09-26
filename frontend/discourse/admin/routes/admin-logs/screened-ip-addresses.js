import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import CurrentUserService from "discourse/services/current-user";

export default class AdminLogsScreenedIpAddressesRoute extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;

  beforeModel() {
    if (!this.currentUser.can_see_ip) {
      this.transitionTo("adminLogs.staffActionLogs");
    }
  }

  setupController() {
    return this.controllerFor("adminLogs.screenedIpAddresses").show();
  }
}
