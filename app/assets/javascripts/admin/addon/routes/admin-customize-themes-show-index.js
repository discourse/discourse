import { action } from "@ember/object";
import { service } from "@ember/service";
import { scrollTop } from "discourse/lib/scroll-top";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowIndexRoute extends DiscourseRoute {
  @service dialog;

  async model() {
    return this.modelFor("adminCustomizeThemesShow");
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    const parentController = this.controllerFor("adminCustomizeThemes");

    controller.setProperties({
      model,
      parentController,
      allThemes: parentController.get("model"),
      colorSchemeId: model.get("color_scheme_id"),
      colorSchemes: parentController.get("model.extras.color_schemes"),
      editingName: false,
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
    if (model.warnUnassignedComponent) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: i18n("admin.customize.theme.unsaved_parent_themes"),
        didConfirm: () => {
          model.set("recentlyInstalled", false);
          transition.retry();
        },
        didCancel: () => model.set("recentlyInstalled", false),
      });
    }
  }
}
