import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";
import SiteSetting from "admin/models/site-setting";

export default class AdminBackupsSettingsRoute extends DiscourseRoute {
  queryParams = {
    filter: { replace: true },
  };

  titleToken() {
    return I18n.t("admin.backups.settings");
  }

  async model(params) {
    return {
      settings: await SiteSetting.findAll({ categories: ["backups"] }),
      initialFilter: params.filter,
    };
  }
}
