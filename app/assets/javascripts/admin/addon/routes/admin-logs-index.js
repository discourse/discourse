import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminLogsIndexRoute extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.transitionTo("adminLogs.staffActionLogs");
  }
}
