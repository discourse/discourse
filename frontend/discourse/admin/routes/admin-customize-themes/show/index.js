import { action } from "@ember/object";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import {
  settingAnchorId,
  settingNameFromFragment,
} from "discourse/admin/lib/setting-anchor";
import discourseLater from "discourse/lib/later";
import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowIndexRoute extends DiscourseRoute {
  @service dialog;

  #arrivalSetting = null;

  async model() {
    return this.modelFor("adminCustomizeThemes.show");
  }

  setupController(controller, model, transition) {
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

    // Only a fresh page load (the app's first transition) jumps to a setting
    // named in the URL's hash. Hash links followed inside the app are scrolled
    // by DiscourseURL, and later transitions must not reuse an earlier hash.
    this.#arrivalSetting = transition?.from
      ? null
      : settingNameFromFragment(window.location.hash);
  }

  @action
  didTransition() {
    const name = this.#arrivalSetting;
    this.#arrivalSetting = null;
    if (!name) {
      scrollTop();
      return;
    }

    // Wait a runloop: the route-scroll-manager service scrolls to the top
    // (or the remembered position) in this transition's afterRender queue,
    // after ours, and would undo the scroll to the setting.
    next(() => this.#arriveAtSetting(name));
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

  #arriveAtSetting(name) {
    const row = document.getElementById(settingAnchorId(name));
    if (!row) {
      return;
    }

    const reduce = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    row.scrollIntoView({
      block: "center",
      behavior: reduce ? "auto" : "smooth",
    });
    const heading = row.querySelector(".setting-label h3");
    heading?.setAttribute("tabindex", "-1");
    heading?.focus({ preventScroll: true });
    row.classList.add("--highlighted");
    discourseLater(() => row.classList.remove("--highlighted"), 2000);
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
