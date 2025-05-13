import Route from "@ember/routing/route";
import { service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";

export default class AdminSchemaRoute extends Route {
  @service routeHistory;

  async model(params) {
    const [, pluginSettings] = await SiteSetting.findAll({
      names: [params.setting_name],
    });

    const [setting] = pluginSettings.siteSettings;

    try {
      setting.value = JSON.parse(setting.value);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(
        `Failed to parse plugin setting ${setting.setting} value: ${setting.value}`,
        e
      );
      setting.value = {};
    }
    setting.updateSetting = (settingName, value) => {
      return SiteSetting.update(settingName, JSON.stringify(value));
    };

    return {
      setting,
      settingName: params.setting_name,
      goBackUrl: this.routeHistory.lastURL,
    };
  }
}
