import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowIndexRoute extends DiscourseRoute {
  @service dialog;

  async model() {
    return this.modelFor("adminCustomizeThemes.show");
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    const parentController = this.controllerFor("adminCustomizeThemes");

    controller.setProperties({
      model,
      parentController,
      allThemes: parentController.model.content,
      colorSchemeId: model.get("color_scheme_id"),
      darkColorSchemeId: model.get("dark_color_scheme_id"),
      colorSchemes: parentController.get("model.extras.color_schemes"),
      editingName: false,
      parentThemesSaved: false,
      userLocale: parentController.get("model.extras.locale"),
    });
  }

  @action
  didTransition() {
    scrollTop();
  }

  @action
  willTransition(transition) {
    const model = this.controller.model;
    if (
      transition.data.skipLeaveWarnings ||
      this.#isDeleted(model) ||
      this.#staysOnTheme(transition, model)
    ) {
      return;
    }

    const pendingSettings = this.controller.pendingSettings;
    if (pendingSettings.length > 0) {
      transition.abort();

      this.dialog.confirm({
        message: i18n("admin.customize.theme.unsaved_changes_alert"),
        confirmButtonClass: "btn-danger",
        confirmButtonLabel: "admin.customize.theme.discard",
        cancelButtonLabel: "admin.customize.theme.stay",
        didConfirm: () => {
          // Settings outlive the page, so unsaved values would reappear on return
          pendingSettings.forEach((setting) => setting.rollback());
          this.#leave(transition);
        },
      });
    } else if (
      model.warnUnassignedComponent &&
      // Saving the theme selection, even to empty, is a deliberate choice
      !this.controller.parentThemesSaved
    ) {
      transition.abort();

      this.dialog.confirm({
        message: i18n("admin.customize.theme.unsaved_parent_themes"),
        confirmButtonLabel: "admin.customize.theme.leave",
        cancelButtonLabel: "admin.customize.theme.stay",
        didConfirm: () => this.#leave(transition),
        didCancel: () => {
          // After render, so we win over the dialog restoring focus on close
          schedule("afterRender", () =>
            document
              .querySelector(".parent-themes-setting .select-kit-header")
              ?.focus()
          );
        },
      });
    }
  }

  #leave(transition) {
    // `data` is carried over to the retried transition
    transition.data.skipLeaveWarnings = true;
    transition.retry();
  }

  #isDeleted(model) {
    return !this.modelFor("adminCustomizeThemes").content.includes(model);
  }

  #staysOnTheme(transition, model) {
    const themeId = transition.to?.find((info) => info.params?.theme_id)?.params
      .theme_id;
    return parseInt(themeId, 10) === model.id;
  }
}
