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

    try {
      await updateClassification(
        async () => {
          const suggestion = await ajax(
            `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
            { type: "POST" }
          );
          if (communityRules.length === 1) {
            suggestion.community_rule = null;
          }
          if (!this.isDestroying) {
            this.message =
              suggestion.community_rule || suggestion.category
                ? null
                : i18n("discourse_ai.dsa_classification.no_suggestion");
          }
          return suggestion;
        },
        SuggestionHint,
        {
          community_rule: communityRules.length > 1 && LoadingHint,
          category: LoadingHint,
        }
      );
    } catch (error) {
      if (!this.isDestroying) {
        this.message = extractError(error);
      }
    }
  }

  <template>
    <div role="status" {{didInsert this.suggest}}>
      {{#if @outletArgs.loading}}
        <span class="sr-only">{{i18n
            "discourse_ai.ai_helper.context_menu.loading"
          }}</span>
      {{else if this.message}}
        <p>{{this.message}}</p>
      {{/if}}
    </div>
  </template>
}
