import Route from "@ember/routing/route";
import SiteSetting from "admin/models/site-setting";

export default class AdminPluginsShowSchemaRoute extends Route {
  async model(params) {
    const plugin = this.modelFor("adminPlugins.show");

    const [pluginSettings] = await SiteSetting.findAll({
      plugin: plugin.id,
    });

    const setting = pluginSettings.siteSettings.find(
      (s) => s.setting === params.setting_name
    );
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
    setting.updateSetting = async (_pluginId, value) => {
      return SiteSetting.update(setting.setting, JSON.stringify(value));
    };

    return {
      plugin,
      setting,
      settingName: params.setting_name,
    };
  }
}
