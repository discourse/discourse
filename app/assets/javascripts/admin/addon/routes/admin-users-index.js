import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminUsersIndexRoute extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.transitionTo("adminUsersList");
  }
}
