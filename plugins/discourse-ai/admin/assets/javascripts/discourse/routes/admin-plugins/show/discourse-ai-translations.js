import SiteSetting, {
  isSettingValueTrue,
} from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { TRANSLATION_SETTING_NAMES } from "../../../lib/ai-translation-settings.js";

export default class DiscourseAiTranslationsRoute extends DiscourseRoute {
  async model() {
    const [overview, { site_settings }] = await Promise.all([
      ajax("/admin/plugins/discourse-ai/ai-translations.json"),
      ajax("/admin/config/site_settings.json", {
        data: { filter_names: TRANSLATION_SETTING_NAMES },
      }),
    ]);
    // Save prerequisites (such as supported locales) before their dependents.
    const settings = TRANSLATION_SETTING_NAMES.map((name) =>
      site_settings.find((setting) => setting.setting === name)
    )
      .filter(Boolean)
      .map((setting) => SiteSetting.create(setting));
    const formData = Object.fromEntries(
      settings.map((setting) => [
        setting.setting,
        setting.type === "bool"
          ? isSettingValueTrue(setting.value)
          : setting.value,
      ])
    );
    return { ...overview, settings, formData };
  }
}
