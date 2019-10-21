import DiscourseRoute from "discourse/routes/discourse";
import { scrollTop } from "discourse/mixins/scroll-top";

export default DiscourseRoute.extend({
  activate() {
    this.controllerFor("admin-dashboard").fetchProblems();
    this.controllerFor("admin-dashboard").fetchDashboard();
    scrollTop();
  }
});
