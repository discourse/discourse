import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersIndexRoute extends DiscourseRoute {
  redirect() {
    this.transitionTo("adminUsersList");
  }
}
