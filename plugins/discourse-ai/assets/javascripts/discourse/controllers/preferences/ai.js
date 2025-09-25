import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";

export default class PreferencesAiController extends Controller {
  @service siteSettings;

  @tracked saved = false;

  get booleanSettings() {
    return [
      {
        key: "ai_search_discoveries",
        label: "discourse_ai.discobot_discoveries.user_setting",
        settingName: "ai-search-discoveries",
        checked: this.model.user_option.ai_search_discoveries,
        isIncluded: (() => {
          return (
            this.siteSettings.ai_discover_persona &&
            this.model?.can_use_ai_discover_persona &&
            this.siteSettings.ai_discover_enabled
          );
        })(),
      },
    ];
  }

  get userSettingAttributes() {
    const attrs = [];

    this.booleanSettings.forEach((setting) => {
      if (setting.isIncluded) {
        attrs.push(setting.key);
      }
    });

    return attrs;
  }

  @action
  save() {
    this.saved = false;

    return this.model
      .save(this.userSettingAttributes)
      .then(() => {
        this.saved = true;
        if (!isTesting()) {
          location.reload();
        }
      })
      .catch(popupAjaxError);
  }
}
