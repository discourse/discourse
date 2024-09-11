import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminConfigThemesIndexRoute extends DiscourseRoute {
  async model() {
    const themes = await this.store.findAll("theme");
    return themes.reject((t) => t.component);
  }

  titleToken() {
    return I18n.t("admin.config_areas.themes.title");
  }
}
