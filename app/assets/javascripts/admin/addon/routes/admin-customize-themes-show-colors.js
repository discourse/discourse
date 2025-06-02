import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesShowColorsRoute extends Route {
  @service dialog;
  @service colorPaletteChangeTracker;

  @action
  willTransition(transition) {
    if (
      this.colorPaletteChangeTracker.dirtyColorsCount > 0 &&
      transition.intent.name !== "adminCustomizeThemes.show.index"
    ) {
      transition.abort();
      this.dialog.yesNoConfirm({
        message: i18n(
          "admin.customize.theme.unsaved_colors_leave_route_confirmation"
        ),
        didConfirm: () => {
          this.colorPaletteChangeTracker.clear();
          transition.retry();
        },
      });
    }
  }
}
