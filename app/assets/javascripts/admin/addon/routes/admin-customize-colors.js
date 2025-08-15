import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { hash } from "rsvp";
import ColorScheme from "admin/models/color-scheme";

export default class AdminCustomizeColorsRoute extends Route {
  @service store;

  model() {
    return hash({
      colorSchemes: ColorScheme.findAll(),
      themes: this.store.findAll("theme"),
    });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("model", model.colorSchemes);

    const themes = model.themes || [];
    const defaultTheme = themes.findBy ? themes.findBy("default", true) : null;

    controller.set("defaultTheme", defaultTheme);

    if (defaultTheme) {
      controller._captureInitialState();
    }
  }
}
