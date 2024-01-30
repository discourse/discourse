import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import { scrollTop } from "discourse/mixins/scroll-top";
import I18n from "discourse-i18n";
import { COMPONENTS, THEMES } from "admin/models/theme";

export default class AdminCustomizeThemesEditorRoute extends Route {
  @service dialog;
  @service router;

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id, 10));
    if (model) {
      return {
        theme: model,
        setting: params.setting,
      };
    } else {
      this.router.replaceWith("adminCustomizeThemes.index");
    }
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    const parentController = this.controllerFor("adminCustomizeThemes");

    parentController.set("editingTheme", true);
    controller.setProperties({
      theme: model.theme,
      settingName: model.setting,
    });
  }
}
