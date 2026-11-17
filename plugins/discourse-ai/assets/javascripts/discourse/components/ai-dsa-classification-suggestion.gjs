import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const LoadingHint = <template>
  <span class="ai-dsa-loading-hint">
    {{dIcon "spinner"}}
    {{i18n "discourse_ai.ai_helper.context_menu.loading"}}
  </span>
</template>;

const SuggestionHint = <template>
  {{dIcon "discourse-sparkles"}}
  {{i18n "discourse_ai.dsa_classification.suggested_by_ai"}}
</template>;

function errorHint(message) {
  return <template>{{dIcon "triangle-exclamation"}} {{message}}</template>;
}

export default class AiDsaClassificationSuggestion extends Component {
  static shouldRender(_outletArgs, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled &&
      !!siteSettings.ai_dsa_classification_decision_model
    );
  }

  @tracked message;

  @action
  async suggest() {
    const { communityRules, reviewableId, updateClassification } =
      this.args.outletArgs;

    const suggestRule = communityRules.length > 1;
    await updateClassification(
      async () => {
        let reason;
        try {
          const suggestion = await ajax(
            `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
            { type: "POST" }
          );
          const community_rule = suggestRule && suggestion.community_rule;
          const category = suggestion.category;
          if (community_rule || category) {
            return { community_rule, category };
          }
          reason = i18n("discourse_ai.dsa_classification.no_suggestion");
        } catch (error) {
          reason =
            error.jqXHR?.responseJSON?.error_type === "rate_limit"
              ? i18n("discourse_ai.dsa_classification.rate_limit")
              : extractError(error);
        }
        if (!this.isDestroying) {
          this.message = reason;
        }
        return {
          fieldHints: {
            community_rule:
              suggestRule &&
              errorHint(
                i18n("discourse_ai.dsa_classification.rule_error", { reason })
              ),
            category: errorHint(
              i18n("discourse_ai.dsa_classification.category_error", { reason })
            ),
          },
        };
      },
      SuggestionHint,
      { community_rule: suggestRule && LoadingHint, category: LoadingHint }
    );
  }

  <template>
    <div class="sr-only" role="status" {{didInsert this.suggest}}>
      {{#if @outletArgs.loading}}
        {{i18n "discourse_ai.ai_helper.context_menu.loading"}}
      {{else if this.message}}
        {{this.message}}
      {{/if}}
    </div>
  </template>
}
