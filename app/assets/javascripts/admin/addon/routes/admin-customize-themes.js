import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import InstallThemeModal from "../components/modal/install-theme";

export default class AdminCustomizeThemesRoute extends Route {
  @service dialog;
  @service router;
  @service modal;

  queryParams = {
    repoUrl: null,
    repoName: null,
  };

  model(params) {
    this.currentTab = params.type;
    return this.store.findAll("theme");
  }

  setupController(controller, model) {
    super.setupController(controller, model);

    if (this.currentTab) {
      controller.setProperties({
        editingTheme: false,
        currentTab: this.currentTab,
      });
    }

    if (controller.repoUrl) {
      next(() => {
        this.modal.show(InstallThemeModal, {
          model: {
            uploadUrl: controller.repoUrl,
            uploadName: controller.repoName,
            selection: "directRepoInstall",
            clearParams: this.clearParams,
            ...this.installThemeOptions(model),
          },
        });
      });
    }
  }

  installThemeOptions(model) {
    return {
      selectedType: this.controller.currentTab,
      userId: model.userId,
      content: model.content,
      installedThemes: this.controller.installedThemes,
      addTheme: this.addTheme,
      updateSelectedType: this.updateSelectedType,
    };
  }

  @action
  routeRefreshModel() {
    this.refresh();
  }

  @action
  installModal() {
    const currentTheme = this.modelFor("adminCustomizeThemes");
    if (this.currentModel?.warnUnassignedComponent) {
      this.dialog.yesNoConfirm({
        message: i18n("admin.customize.theme.unsaved_parent_themes"),
        didConfirm: () => {
          currentTheme.set("recentlyInstalled", false);
          this.modal.show(InstallThemeModal, {
            model: { ...this.installThemeOptions(currentTheme) },
          });
        },
      });
    } else {
      this.modal.show(InstallThemeModal, {
        model: { ...this.installThemeOptions(currentTheme) },
      });
    }
  }

  @action
  updateSelectedType(type) {
    this.controller.set("currentTab", type);
  }

  @action
  clearParams() {
    this.controller.setProperties({
      repoUrl: null,
      repoName: null,
    });
  }

  @action
  addTheme(theme) {
    this.refresh();
    theme.setProperties({ recentlyInstalled: true });
    this.router.transitionTo("adminCustomizeThemes.show", theme.get("id"), {
      queryParams: {
        repoName: null,
        repoUrl: null,
      },
    });
  }
}
