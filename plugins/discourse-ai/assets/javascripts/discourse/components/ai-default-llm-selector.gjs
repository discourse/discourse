import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class AiDefaultLlmSelector extends Component {
  @service toasts;

  @tracked llmModels = [];
  @tracked selectedValue = "";
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    this.#loadData();
  }

  async #loadData() {
    try {
      const modelsResponse = await ajax(
        "/admin/plugins/discourse-ai/ai-llms.json"
      );
      this.llmModels = modelsResponse.ai_llms || [];

      const { site_settings } = await ajax("/admin/config/site_settings.json", {
        data: {
          plugin: "discourse-ai",
          category: "discourse_ai",
        },
      });

      const defaultLlmSetting = site_settings.find(
        (setting) => setting.setting === "ai_default_llm_model"
      );

      const rawValue = defaultLlmSetting?.value;
      this.selectedValue =
        rawValue === null || rawValue === undefined || rawValue === ""
          ? "none"
          : String(rawValue);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get content() {
    const noneOption = {
      id: "none",
      name: i18n("discourse_ai.llm_selector.none"),
    };
    const models = this.llmModels.map((model) => ({
      id: String(model.id),
      name: model.display_name,
    }));
    return [noneOption, ...models];
  }

  @action
  async onChange(value) {
    const previousValue = this.selectedValue;
    this.selectedValue = value;
    this.isSaving = true;

    try {
      const backendValue = value === "none" ? "" : value;
      await ajax("/admin/site_settings/ai_default_llm_model", {
        type: "PUT",
        data: { ai_default_llm_model: backendValue },
      });

      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n("discourse_ai.llm_selector.saved"),
        },
      });
    } catch (error) {
      this.selectedValue = previousValue;
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div class="ai-configure-default-llm">
      <div class="ai-configure-default-llm__header">
        <h3>{{i18n "discourse_ai.default_llm.title"}}</h3>
        <p>{{i18n "discourse_ai.default_llm.description"}}</p>
      </div>

      <div class="ai-configure-default-llm__setting">
        <ComboBox
          @value={{this.selectedValue}}
          @content={{this.content}}
          @onChange={{this.onChange}}
          @valueProperty="id"
          @nameProperty="name"
          @options={{hash disabled=this.isSaving}}
        />
        <ConditionalLoadingSpinner @condition={{this.isSaving}} @size="small" />
      </div>
    </div>
  </template>
}
