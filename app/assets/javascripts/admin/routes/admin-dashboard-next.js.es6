import { scrollTop } from "discourse/mixins/scroll-top";

export default Discourse.Route.extend({
  activate() {
    this.controllerFor("admin-dashboard-next").fetchProblems();
    this.controllerFor("admin-dashboard-next").fetchDashboard();
    scrollTop();
  },

  afterModel(model, transition) {
    if (transition.targetName === "admin.dashboardNext.index") {
      this.transitionTo("admin.dashboardNext.general");
    }
  },

  actions: {
    willTransition(transition) {
      if (transition.targetName === "admin.dashboardNext.index") {
        this.transitionTo("admin.dashboardNext.general");
      }
    }
  }
});
