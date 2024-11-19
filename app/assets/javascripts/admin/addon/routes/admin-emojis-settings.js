import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminEmojisSettingsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return I18n.t("settings");
  }
}
