import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigThemesAndComponentsComponentsRoute extends DiscourseRoute {
  async model() {
    return await ajax("/admin/config/customize/components");
  }

  titleToken() {
    return i18n("admin.config_areas.themes_and_components.components.title");
  }
}
