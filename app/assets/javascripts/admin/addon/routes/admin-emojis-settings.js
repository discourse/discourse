import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";
import SiteSetting from "admin/models/site-setting";

export default class AdminEmojisSettingsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return I18n.t("settings");
  }

  async model() {
    return {
      settings: await SiteSetting.findAll(),
      initialFilter: "emoji",
    };
  }
}
