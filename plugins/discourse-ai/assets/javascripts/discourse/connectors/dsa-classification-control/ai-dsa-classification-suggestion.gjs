import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DsaClassificationSelect from "discourse/components/dsa-classification-select";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiDsaClassificationSuggestion extends Component {
  static shouldRender(outletArgs, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled &&
      !!siteSettings.ai_dsa_classification_decision_model &&
      !!outletArgs.reviewableId
    );
  }

  @service toasts;

  get chooseAction() {
    return {
      label: i18n("discourse_ai.ai_helper.choose"),
      icon: "discourse-sparkles",
      choose: this.suggest,
      completed: i18n("discourse_ai.dsa_classification.updated"),
    };
  }

  @action
  async suggest() {
    try {
      const suggestion = await ajax(
        `/discourse-ai/ai-moderation/dsa-classifications/${this.args.outletArgs.reviewableId}/suggest`,
        { type: "POST" }
      );
      if (this.isDestroying) {
        return;
      }

      const value = suggestion[this.args.outletArgs.fieldName];
      if (!value) {
        this.toasts.error({
          duration: "short",
          data: {
            message: i18n("discourse_ai.dsa_classification.no_suggestion"),
          },
        });
      }
      return value;
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    }
  }

  <template>
    <DsaClassificationSelect
      @chooseAction={{this.chooseAction}}
      @field={{@outletArgs.field}}
      @options={{@outletArgs.options}}
      @placeholder={{@outletArgs.placeholder}}
    />
  </template>
}
