import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminConfigLookAndFeelThemesRoute extends DiscourseRoute {
  async model() {
    const themes = await this.store.findAll("theme");
    return themes.reject((t) => t.component);
  }

  titleToken() {
    return I18n.t("admin.config_areas.look_and_feel.themes.title");
  }
}
