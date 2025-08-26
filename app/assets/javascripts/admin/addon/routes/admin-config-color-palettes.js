import DiscourseRoute from "discourse/routes/discourse";
import ColorScheme from "admin/models/color-scheme";

export default class AdminConfigColorPalettesRoute extends DiscourseRoute {
  /** @returns {any} */
  model() {
    return ColorScheme.findAll({ excludeThemeOwned: true });
  }
}
