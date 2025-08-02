import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserTl3RequirementsRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminUser");
  }
}
