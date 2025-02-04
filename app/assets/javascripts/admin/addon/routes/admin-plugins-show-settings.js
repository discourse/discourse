import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowSettingsRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    filter: { replace: true },
  };

  async model(params) {
    const plugin = this.modelFor("adminPlugins.show");
    return {
      plugin,
      initialFilter: params.filter,
    };
  }

  titleToken() {
    return i18n("admin.plugins.change_settings_short");
  }
}
