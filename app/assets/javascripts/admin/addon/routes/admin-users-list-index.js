import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminUsersListIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("adminUsersList.show", "active");
  }
}
