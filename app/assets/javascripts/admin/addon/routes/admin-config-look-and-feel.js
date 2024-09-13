import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminConfigLookAndFeelRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("admin.config_areas.look_and_feel.title");
  }
}
