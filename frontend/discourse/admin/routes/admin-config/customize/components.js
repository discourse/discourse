import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigThemesAndComponentsComponentsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config_areas.themes_and_components.components.title");
  }
}
