import DiscourseRoute from "discourse/routes/discourse";
import { scrollTop } from "discourse/mixins/scroll-top";

export default class AdminDashboardRoute extends DiscourseRoute {
  activate() {
    this.controllerFor("admin-dashboard").fetchProblems();
    this.controllerFor("admin-dashboard").fetchDashboard();
    scrollTop();
  }
}
