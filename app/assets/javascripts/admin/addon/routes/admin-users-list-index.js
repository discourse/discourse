import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersListIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("adminUsersList.show", "active");
  }
}
