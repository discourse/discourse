import Route from "@ember/routing/route";
import showModal from "discourse/lib/show-modal";

export default Route.extend({
  model() {
    return this.store.findAll("theme");
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set("editingTheme", false);
  },

  actions: {
    installModal() {
      showModal("admin-install-theme", { admin: true });
    },

    addTheme(theme) {
      this.refresh();
      this.transitionTo("adminCustomizeThemes.show", theme.get("id"));
    }
  }
});
