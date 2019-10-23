import Route from "@ember/routing/route";
import showModal from "discourse/lib/show-modal";

export default Route.extend({
  queryParams: {
    q: { replace: true },
    overridden: { replace: true }
  },

  model(params) {
    return this.store.find(
      "site-text",
      Ember.getProperties(params, "q", "overridden")
    );
  },

  setupController(controller, model) {
    controller.set("siteTexts", model);
  },

  actions: {
    showReseedModal() {
      showModal("admin-reseed", { admin: true });
    }
  }
});
