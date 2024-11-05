import Route from "@ember/routing/route";
import ColorScheme from "admin/models/color-scheme";

export default class AdminCustomizeColorsRoute extends Route {
  model() {
    return ColorScheme.findAll();
  }
}
