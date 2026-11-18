import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
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

async function classify(reviewableId, suggestRule) {
  let reason;
  try {
    const { community_rule, category } = await ajax(
      `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
      { type: "POST" }
    );
    const values = {
      ...(suggestRule && community_rule && { community_rule }),
      ...(category && { category }),
    };
    if (Object.keys(values).length) {
      return {
        values,
        fieldHints: {
          community_rule: values.community_rule && SuggestionHint,
          category: values.category && SuggestionHint,
        },
      };
    }
    reason = i18n("discourse_ai.dsa_classification.no_suggestion");
  } catch (error) {
    reason =
      error.jqXHR?.responseJSON?.error_type === "rate_limit"
        ? i18n("discourse_ai.dsa_classification.rate_limit")
        : extractError(error);
  }
  return {
    message: reason,
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
}

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  api.registerBehaviorTransformer(
    "suggest-dsa-classification",
    ({ next, context }) => {
      if (
        !settings.discourse_ai_enabled ||
        !settings.ai_dsa_classification_decision_model
      ) {
        return next();
      }
      const suggestRule = context.communityRules.length > 1;
      return {
        pendingFieldHints: {
          community_rule: suggestRule && LoadingHint,
          category: LoadingHint,
        },
        loadingMessage: i18n("discourse_ai.ai_helper.context_menu.loading"),
        result: classify(context.reviewableId, suggestRule),
      };
    }
  );
});
