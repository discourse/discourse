import showModal from "discourse/lib/show-modal";

export default Ember.Route.extend({
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
      this.transitionTo("adminCustomizeThemes.show", theme.id);
    }
  }
});
