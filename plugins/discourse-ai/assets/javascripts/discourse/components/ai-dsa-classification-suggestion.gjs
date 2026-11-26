import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SuggestionHint = <template>
  {{dIcon "discourse-sparkles"}}
  {{i18n "discourse_ai.dsa_classification.suggested_by_ai"}}
</template>;

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
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const hasSuggestion = await updateClassification(
        () =>
          ajax(
            `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
            { type: "POST" }
          ),
        SuggestionHint
      );

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
      {{didInsert this.suggest}}
    />
  </template>
}
