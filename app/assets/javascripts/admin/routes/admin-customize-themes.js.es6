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
    importModal() {
      showModal("admin-import-theme", { admin: true });
    },

    addTheme(theme) {
      this.refresh();
      this.transitionTo("adminCustomizeThemes.show", theme.get("id"));
    },

    showCreateModal() {
      showModal("admin-create-theme", { admin: true });
    }
  }
});
