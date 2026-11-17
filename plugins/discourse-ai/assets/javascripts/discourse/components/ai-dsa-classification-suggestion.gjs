import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class AiDsaClassificationSuggestion extends Component {
  static shouldRender(_outletArgs, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled &&
      !!siteSettings.ai_dsa_classification_decision_model
    );
  }

  @service a11y;
  @service toasts;

  @tracked loading = false;

  @action
  async suggest() {
    const { reviewableId, updateClassification } = this.args.outletArgs;
    let hasSuggestion = false;
    this.loading = true;
    try {
      await updateClassification(async () => {
        const classification = await ajax(
          `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
          { type: "POST" }
        );
        hasSuggestion = Object.values(classification).some(Boolean);
        return classification;
      });

      if (!this.isDestroying) {
        if (hasSuggestion) {
          this.a11y.announce(i18n("discourse_ai.dsa_classification.updated"));
        } else {
          this.toasts.error({
            duration: "short",
            data: {
              message: i18n("discourse_ai.dsa_classification.no_suggestion"),
            },
          });
        }
      }
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  <template>
    <DButton
      class="btn-default"
      @action={{this.suggest}}
      @disabled={{@outletArgs.disabled}}
      @icon="discourse-sparkles"
      @isLoading={{this.loading}}
      @label="discourse_ai.dsa_classification.suggest"
    />
  </template>
}
