import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { COMPONENTS, THEMES } from "admin/models/theme";
import I18n from "I18n";
import Route from "@ember/routing/route";
import { scrollTop } from "discourse/mixins/scroll-top";

export default class AdminCustomizeThemesShowRoute extends Route {
  @service dialog;
  @service router;

  serialize(model) {
    return { theme_id: model.get("id") };
  }

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id, 10));
    if (model) {
      return model;
    } else {
      this.router.replaceWith("adminCustomizeThemes.index");
    }
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    const parentController = this.controllerFor("adminCustomizeThemes");

    parentController.setProperties({
      editingTheme: false,
      currentTab: model.get("component") ? COMPONENTS : THEMES,
    });

    controller.setProperties({
      model,
      parentController,
      allThemes: parentController.get("model"),
      colorSchemeId: model.get("color_scheme_id"),
      colorSchemes: parentController.get("model.extras.color_schemes"),
      editingName: false,
    });

    this.handleHighlight(model);
  }

  deactivate() {
    this.handleHighlight();
  }

  handleHighlight(theme) {
    this.get("controller.allThemes")
      .filter((t) => t.get("selected"))
      .forEach((t) => t.set("selected", false));
    if (theme) {
      theme.set("selected", true);
    }
  }

  @action
  didTransition() {
    scrollTop();
  }

  @action
  willTransition(transition) {
    const model = this.controller.model;
    if (model.warnUnassignedComponent) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: I18n.t("admin.customize.theme.unsaved_parent_themes"),
        didConfirm: () => {
          model.set("recentlyInstalled", false);
          transition.retry();
        },
        didCancel: () => model.set("recentlyInstalled", false),
      });
    }
  }
}
