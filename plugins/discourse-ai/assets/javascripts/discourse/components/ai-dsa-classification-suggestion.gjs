import Component from "@glimmer/component";
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

  @action
  async suggest() {
    const form = this.args.outletArgs.getForm();
    const fields = ["community_rule", "category"];
    const previousValues = fields.map((field) => form.get(field));
    this.args.outletArgs.onLoadingChange(true);

    try {
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
        suggestion[field] && form.get(field) === previousValues[index]
          ? [form.set(field, suggestion[field])]
          : []
      );
      if (updates.length) {
        await Promise.all(updates);
        this.a11y.announce(i18n("discourse_ai.dsa_classification.updated"));
      }
    } catch (error) {
      if (!this.isDestroying) {
        popupAjaxError(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.args.outletArgs.onLoadingChange(false);
      }
    }
  }

  <template>
    <DButton
      class="btn-default"
      @action={{this.suggest}}
      @disabled={{@outletArgs.disabled}}
      @icon="discourse-sparkles"
      @isLoading={{@outletArgs.loading}}
      @label="discourse_ai.dsa_classification.suggest"
    />
  </template>
}
