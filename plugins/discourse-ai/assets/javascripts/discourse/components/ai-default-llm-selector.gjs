import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

export default class AiDefaultLlmSelector extends Component {
  @tracked defaultLlmSetting = null;

  constructor() {
    super(...arguments);
    this.#loadDefaultLlmSetting();
  }

  async #loadDefaultLlmSetting() {
    const { site_settings } = await ajax("/admin/config/site_settings.json", {
      data: {
        plugin: "discourse-ai",
        category: "discourse_ai",
      },
    });

    const defaultLlmSetting = site_settings.find(
      (setting) => setting.setting === "ai_default_llm_model"
    );

    this.defaultLlmSetting = SiteSetting.create(defaultLlmSetting);
  }

  <template>
    <div class="ai-configure-default-llm">
      <div class="ai-configure-default-llm__header">
        <h3>{{i18n "discourse_ai.default_llm.title"}}</h3>
        <p>{{i18n "discourse_ai.default_llm.description"}}</p>
      </div>

      {{#if this.defaultLlmSetting}}
        <SiteSettingComponent
          @setting={{this.defaultLlmSetting}}
          class="ai-configure-default-llm__setting"
        />
      {{/if}}
    </div>
  </template>
}
