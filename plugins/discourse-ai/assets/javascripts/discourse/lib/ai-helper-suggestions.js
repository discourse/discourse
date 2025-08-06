import { getOwner } from "@ember/application";
import { later } from "@ember/runloop";
import { i18n } from "discourse-i18n";

export const MIN_CHARACTER_COUNT = 40;

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
