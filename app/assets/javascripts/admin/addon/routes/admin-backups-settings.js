import Route from "@ember/routing/route";
import { service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";

export default class AdminBackupsSettingsRoute extends Route {
  @service router;

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
