import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

async function suggest(reviewableId) {
  let suggestion;
  let reason = i18n("discourse_ai.dsa_classification.no_suggestion");
  try {
    suggestion = await ajax(
      `/discourse-ai/ai-moderation/dsa-classifications/${reviewableId}/suggest`,
      { type: "POST" }
    );
  } catch (error) {
    reason =
      error.jqXHR?.responseJSON?.error_type === "rate_limit"
        ? i18n("discourse_ai.dsa_classification.rate_limit")
        : extractError(error);
  }

  const { community_rule, category } = suggestion ?? {};
  const label = i18n("discourse_ai.dsa_classification.suggested_by_ai");
  const outcomes = {};
  if (community_rule) {
    outcomes.communityRule = { value: community_rule, label };
  } else if (!category) {
    outcomes.communityRule = {
      errorLabel: i18n("discourse_ai.dsa_classification.rule_error", {
        reason,
      }),
    };
  }
  if (community_rule && !category) {
    reason = i18n("discourse_ai.dsa_classification.no_category");
  }
  outcomes.category = category
    ? { value: category, label }
    : {
        errorLabel: i18n("discourse_ai.dsa_classification.category_error", {
          reason,
        }),
      };
  return outcomes;
}

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  if (
    settings.discourse_ai_enabled &&
    settings.ai_dsa_classification_decision_model
  ) {
    api.registerReviewableDsaSuggestionProvider({
      loadingLabel: i18n("discourse_ai.ai_helper.context_menu.loading"),
      suggest,
    });
  }
});
