import Route from "@ember/routing/route";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import ColorScheme from "discourse/admin/models/color-scheme";
import Theme from "discourse/admin/models/theme";
import { ajax } from "discourse/lib/ajax";

export default class AdminConfigColorPalettesIndexRoute extends Route {
  async model() {
    const value = await ajax("/admin/config/colors");
    return value;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    const defaultTheme = model.extras.default_theme
      ? Theme.create(model.extras.default_theme)
      : null;
    controller.set(
      "model",
      new TrackedArray(
        model.palettes.map((palette) => ColorScheme.create(palette))
      )
    );
    controller.set("defaultTheme", defaultTheme);

    if (defaultTheme) {
      controller._captureInitialState();
    }
  }
}
