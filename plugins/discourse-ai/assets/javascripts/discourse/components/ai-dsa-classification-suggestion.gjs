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

  #releaseSubmission;

  willDestroy() {
    super.willDestroy();
    this.#releaseSubmission?.();
  }

  @action
  async suggest() {
    this.loading = true;
    this.#releaseSubmission = this.args.outletArgs.blockSubmission();
    try {
      await this.#applySuggestion();
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    } finally {
      this.#releaseSubmission?.();
      this.#releaseSubmission = undefined;
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  async #applySuggestion() {
    const form = this.args.outletArgs.getForm();
    const fields = ["community_rule", "category"];
    const fieldRevision = this.args.outletArgs.fieldRevision;
    const revisions = fields.map(fieldRevision);
    const suggestion = await ajax(
      `/discourse-ai/ai-moderation/dsa-classifications/${this.args.outletArgs.reviewableId}/suggest`,
      { type: "POST" }
    );
    if (this.isDestroying) {
      return;
    }

    if (!suggestion.community_rule && !suggestion.category) {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("discourse_ai.dsa_classification.no_suggestion"),
        },
      });
      return;
    }

    const updates = fields.flatMap((field, index) =>
      suggestion[field] && fieldRevision(field) === revisions[index]
        ? [form.set(field, suggestion[field])]
        : []
    );
    if (updates.length) {
      await Promise.all(updates);
      if (!this.isDestroying) {
        this.a11y.announce(i18n("discourse_ai.dsa_classification.updated"));
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
