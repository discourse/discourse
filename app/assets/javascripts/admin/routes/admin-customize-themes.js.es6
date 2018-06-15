import showModal from "discourse/lib/show-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";

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
      const all = this.modelFor("adminCustomizeThemes");
      all.pushObject(theme);
      this.transitionTo("adminCustomizeThemes.show", theme.get("id"));
    },

    newTheme(obj) {
      obj = obj || { name: I18n.t("admin.customize.new_style") };
      const item = this.store.createRecord("theme");

      item
        .save(obj)
        .then(() => {
          this.send("addTheme", item);
        })
        .catch(popupAjaxError);
    }
  }
});
