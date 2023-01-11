import Route from "@ember/routing/route";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default Route.extend({
  dialog: service(),

  queryParams: {
    repoUrl: null,
    repoName: null,
  },

  model() {
    return this.store.findAll("theme");
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set("editingTheme", false);

    if (controller.repoUrl) {
      next(() => {
        showModal("admin-install-theme", {
          admin: true,
        }).setProperties({
          uploadUrl: controller.repoUrl,
          uploadName: controller.repoName,
          selection: "directRepoInstall",
        });
      });
    }
  },

  actions: {
    installModal() {
      const currentTheme = this.controllerFor(
        "adminCustomizeThemes.show"
      ).model;
      if (currentTheme?.warnUnassignedComponent) {
        this.dialog.yesNoConfirm({
          message: I18n.t("admin.customize.theme.unsaved_parent_themes"),
          didConfirm: () => {
            currentTheme.set("recentlyInstalled", false);
            showModal("admin-install-theme", { admin: true });
          },
        });
      } else {
        showModal("admin-install-theme", { admin: true });
      }
    },

    addTheme(theme) {
      this.refresh();
      theme.setProperties({ recentlyInstalled: true });
      this.transitionTo("adminCustomizeThemes.show", theme.get("id"), {
        queryParams: {
          repoName: null,
          repoUrl: null,
        },
      });
    },
  },
});
