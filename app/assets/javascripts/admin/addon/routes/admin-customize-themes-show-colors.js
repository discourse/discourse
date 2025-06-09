import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowColorsRoute extends DiscourseRoute {
  @service dialog;

  @action
  willTransition(transition) {
    if (
      this.controller.colorPaletteChangeTracker.dirtyColorsCount > 0 &&
      transition.intent.name !== "adminCustomizeThemes.show.index"
    ) {
      transition.abort();
      this.dialog.yesNoConfirm({
        message: i18n(
          "admin.customize.theme.unsaved_colors_leave_route_confirmation"
        ),
        didConfirm: () => {
          this.controller.colorPaletteChangeTracker.clear();
          transition.retry();
        },
      });
    }
  }

  titleToken() {
    return i18n("admin.customize.theme.colors_title");
  }
}
