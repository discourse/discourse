import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class AiDsaClassificationSuggestion extends Component {
  static shouldRender(outletArgs, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled &&
      !!siteSettings.ai_dsa_classification_decision_model &&
      !!outletArgs.reviewable?.id
    );
  }

  @tracked loading = false;
  @tracked message = null;
  @tracked failed = false;

  @action
  async suggest() {
    this.loading = true;
    this.message = null;
    this.failed = false;

    try {
      const suggestion = await ajax(
        `/discourse-ai/ai-moderation/dsa-classifications/${this.args.outletArgs.reviewable.id}/suggest`,
        { type: "POST" }
      );
      // Staff may close the modal while the model is still answering.
      if (this.isDestroying) {
        return;
      }

      const values = Object.fromEntries(
        Object.entries(suggestion).filter(([, value]) => value)
      );

      if (Object.keys(values).length) {
        await this.args.outletArgs.form.setProperties(values);
        this.message = i18n("discourse_ai.dsa_classification.suggested");
      } else {
        this.message = i18n("discourse_ai.dsa_classification.no_suggestion");
      }
    } catch (error) {
      if (!this.isDestroying) {
        this.failed = true;
        this.message = extractError(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  <template>
    <div class="ai-dsa-classification-suggestion">
      <DButton
        class="btn-default ai-dsa-classification-suggestion__button"
        @action={{this.suggest}}
        @disabled={{this.loading}}
        @icon="discourse-sparkles"
        @isLoading={{this.loading}}
        @label="discourse_ai.dsa_classification.suggest"
      />
      <span
        aria-live="polite"
        class="ai-dsa-classification-suggestion__message
          {{if this.failed '--error'}}"
      >{{this.message}}</span>
    </div>
  </template>
}
