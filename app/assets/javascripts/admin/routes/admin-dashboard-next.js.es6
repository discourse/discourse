import { scrollTop } from "discourse/mixins/scroll-top";

export default Discourse.Route.extend({
  activate() {
    this.controllerFor("admin-dashboard-next").fetchProblems();
    this.controllerFor("admin-dashboard-next").fetchDashboard();
    scrollTop();
  }
});
