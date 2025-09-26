import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import ColorScheme from "admin/models/color-scheme";
import Theme from "admin/models/theme";

export default class AdminConfigColorPalettesIndexRoute extends Route {
  @service store;

  async model() {
    return await ajax("/admin/config/colors");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    const defaultTheme = model.extras.default_theme
      ? Theme.create(model.extras.default_theme)
      : null;
    controller.set(
      "model",
      model.palettes.map((palette) => ColorScheme.create(palette))
    );
    controller.set("defaultTheme", defaultTheme);

    if (defaultTheme) {
      controller._captureInitialState();
    }
  }
}
