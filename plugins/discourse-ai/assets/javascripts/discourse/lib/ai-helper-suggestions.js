import { getOwner } from "@ember/owner";
import { later } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { isAiCreditLimitError, popupAiCreditLimitError } from "./ai-errors";

export const MIN_CHARACTER_COUNT = 40;

// Fetches title suggestions from the server. Returns the suggestions array,
// or null when the request failed (the relevant error is shown to the user).
export async function fetchTitleSuggestions({ text, topicId }) {
  const data = text ? { text } : { topic_id: topicId };

  try {
    const { suggestions } = await ajax(
      "/discourse-ai/ai-helper/suggest_title",
      { method: "POST", data }
    );
    return suggestions;
  } catch (error) {
    if (isAiCreditLimitError(error)) {
      popupAiCreditLimitError(error);
    } else {
      popupAjaxError(error);
    }
    return null;
  }
}

export function tagNames(tags) {
  return (tags ?? [])
    .map((tag) => (typeof tag === "string" ? tag : tag?.name))
    .filter(Boolean);
}

export function tagSuggestionParams(categoryId, tags) {
  const params = {};

  if (categoryId) {
    params.category_id = categoryId;
  }

  const selectedTags = tagNames(tags);
  if (selectedTags.length) {
    params.selected_tags = selectedTags;
  }

  return params;
}

export function showSuggestionsError(context, reloadFn) {
  const toasts = getOwner(context).lookup("service:toasts");

  toasts.error({
    class: "ai-suggestion-error",
    duration: "long",
    showProgressBar: true,
    data: {
      message: i18n("discourse_ai.ai_helper.suggest_errors.no_suggestions"),
      actions: [
        {
          label: i18n("discourse_ai.ai_helper.context_menu.regen"),
          icon: "rotate",
          class: "btn btn-small",
          action: async (toast) => {
            toast.close();

            await reloadFn();

            if (context.dMenu?.show && context.suggestions?.length > 0) {
              later(() => context.dMenu.show(), 50);
            }
          },
        },
      ],
    },
  });
}
