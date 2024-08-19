import Route from "@ember/routing/route";
import SiteSetting from "admin/models/site-setting";

export default class AdminBackupsSettingsRoute extends Route {
  queryParams = {
    filter: { replace: true },
  };

  async model(params) {
    return {
      settings: await SiteSetting.findAll({ categories: ["backups"] }),
      initialFilter: params.filter,
    };
  }
}
