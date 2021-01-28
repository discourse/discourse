import Route from "@ember/routing/route";
import { getProperties } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default Route.extend({
  queryParams: {
    q: { replace: true },
    overridden: { replace: true },
    locale: { replace: true },
  },

  model(params) {
    return this.store.find(
      "site-text",
      getProperties(params, "q", "overridden", "locale")
    );
  },

  setupController(controller, model) {
    controller.set("siteTexts", model);
  },

  actions: {
    showReseedModal() {
      showModal("admin-reseed", { admin: true });
    },
  },
});
