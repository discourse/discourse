import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsIndexRoute extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.transitionTo("adminLogs.staffActionLogs");
  }
}
