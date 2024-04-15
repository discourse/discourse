import { scrollTop } from "discourse/mixins/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardRoute extends DiscourseRoute {
  activate() {
    this.controllerFor("admin-dashboard").fetchProblems();
    this.controllerFor("admin-dashboard").fetchDashboard();
    scrollTop();
  }
}
