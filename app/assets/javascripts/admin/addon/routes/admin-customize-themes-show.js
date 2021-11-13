import { COMPONENTS, THEMES } from "admin/models/theme";
import I18n from "I18n";
import Route from "@ember/routing/route";
import { scrollTop } from "discourse/mixins/scroll-top";
import bootbox from "bootbox";

export function showUnassignedComponentWarning(theme, callback) {
  bootbox.confirm(
    I18n.t("admin.customize.theme.unsaved_parent_themes"),
    I18n.t("admin.customize.theme.discard"),
    I18n.t("admin.customize.theme.stay"),
    (result) => {
      if (!result) {
        theme.set("recentlyInstalled", false);
      }
      callback(result);
    }
  );
}

export default Route.extend({
  serialize(model) {
    return { theme_id: model.get("id") };
  },

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id, 10));
    return model ? model : this.replaceWith("adminCustomizeThemes.index");
  },

  setupController(controller, model) {
    this._super(...arguments);

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
  },

  deactivate() {
    this.handleHighlight();
  },

  handleHighlight(theme) {
    this.get("controller.allThemes")
      .filter((t) => t.get("selected"))
      .forEach((t) => t.set("selected", false));
    if (theme) {
      theme.set("selected", true);
    }
  },

  actions: {
    didTransition() {
      scrollTop();
    },
    willTransition(transition) {
      const model = this.controller.model;
      if (model.warnUnassignedComponent) {
        transition.abort();
        showUnassignedComponentWarning(model, (result) => {
          if (!result) {
            transition.retry();
          }
        });
      }
    },
  },
});
