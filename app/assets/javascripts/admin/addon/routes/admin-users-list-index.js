import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersListIndexRoute extends DiscourseRoute {
  beforeModel() {
    this.transitionTo("adminUsersList.show", "active");
  }
}
