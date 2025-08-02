import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersIndexRoute extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.transitionTo("adminUsersList");
  }
}
