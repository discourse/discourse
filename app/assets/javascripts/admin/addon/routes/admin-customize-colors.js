import ColorScheme from "admin/models/color-scheme";
import Route from "@ember/routing/route";

export default class AdminCustomizeColorsRoute extends Route {
  model() {
    return ColorScheme.findAll();
  }

  setupController(controller, model) {
    controller.set("model", model);
  }
}
