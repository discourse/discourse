import Route from "@ember/routing/route";
import showModal from "discourse/lib/show-modal";
import { showUnassignedComponentWarning } from "admin/routes/admin-customize-themes-show";

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
      const currentTheme = this.controllerFor("adminCustomizeThemes.show")
        .model;
      if (currentTheme && currentTheme.warnUnassignedComponent) {
        showUnassignedComponentWarning(currentTheme, (result) => {
          if (!result) {
            showModal("admin-install-theme", { admin: true });
          }
        });
      } else {
        showModal("admin-install-theme", { admin: true });
      }
    },

    addTheme(theme) {
      this.refresh();
      theme.setProperties({ recentlyInstalled: true });
      this.transitionTo("adminCustomizeThemes.show", theme.get("id"));
    },
  },
});
