import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import {
  chooserSuggestionContext,
  chooserSuggestionContextFromInstance,
} from "../lib/chooser-suggestion-context.js";
import { showComposerAiHelper } from "../lib/show-ai-helper.js";

const SUGGEST_ID = "ai-category-suggest";

const STATE = new WeakMap();

function stateFor(component) {
  let state = STATE.get(component);
  if (!state) {
    state = { loading: false };
    STATE.set(component, state);
  }
  return state;
}

function noSuggestionsToast(component) {
  getOwner(component)
    .lookup("service:toasts")
    .error({
      duration: "short",
      data: {
        message: i18n("discourse_ai.ai_helper.suggest_errors.no_suggestions"),
      },
    });
}

async function applyBestSuggestion(component, selectKit, context) {
  const state = stateFor(component);
  const data = context.categoryRequestData();

  if (!data) {
    noSuggestionsToast(component);
    return;
  }

  const startValue = selectKit.value;
  state.loading = true;
  selectKit.close();
  selectKit.set("isLoading", true);

  try {
    const { assistant } = await ajax(
      "/discourse-ai/ai-helper/suggest_category",
      { method: "POST", data }
    );

    if (component.isDestroying) {
      return;
    }

    if (selectKit.value !== startValue) {
      return;
    }

    const best = (assistant || [])[0];
    if (best) {
      selectKit.select(best.id, { id: best.id, name: best.name });
    } else {
      noSuggestionsToast(component);
    }
  } catch (error) {
    popupAjaxError(error);
  } finally {
    state.loading = false;
    if (!component.isDestroying) {
      selectKit.set("isLoading", false);
    }
  }
}

function triggerRow(component, context) {
  return {
    id: SUGGEST_ID,
    name: i18n("discourse_ai.ai_helper.choose"),
    icon: "discourse-sparkles",
    classNames: "ai-category-suggest-row",
    onSelect: (selectKit) => applyBestSuggestion(component, selectKit, context),
  };
}

function enabledFor(context, siteSettings, currentUser) {
  return (
    !!context &&
    siteSettings.ai_embeddings_enabled &&
    context.categoryChooserEnabled &&
    showComposerAiHelper(
      context.model,
      siteSettings,
      currentUser,
      "suggestions"
    )
  );
}

async function applyNewSuggestion(control, context, { toasts, a11y }) {
  const noSuggestions = () => {
    const message = i18n(
      "discourse_ai.ai_helper.suggest_errors.no_suggestions"
    );
    toasts.error({ duration: "short", data: { message } });
    a11y.announce(message);
  };

  const data = context.categoryRequestData();
  if (!data) {
    noSuggestions();
    return;
  }

  control.close();
  await control.update(async (scope) => {
    const request = ajax("/discourse-ai/ai-helper/suggest_category", {
      method: "POST",
      data,
    });
    // The ajax helper ignores abort signals, so a newer selection cancels the request itself.
    scope.signal.addEventListener("abort", () => request.abort(), {
      once: true,
    });

    try {
      const { assistant } = await request;
      if (!scope.current) {
        return;
      }

      const best = assistant?.[0];
      if (best) {
        scope.select({ ...best, id: Number(best.id) });
      } else {
        noSuggestions();
      }
    } catch (error) {
      if (!scope.signal.aborted) {
        popupAjaxError(error);
      }
    }
  });
}

function initInlineCategorySuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  api.registerValueTransformer(
    "select-customizations",
    ({ value: selects }) => {
      for (const identifier of ["composer-category", "topic-edit-category"]) {
        selects.forIdentifier(identifier, (spec) => {
          spec.content((items, { filter, instanceContext, control }) => {
            const context =
              chooserSuggestionContextFromInstance(instanceContext);
            if (
              filter ||
              control.pending ||
              !enabledFor(context, siteSettings, currentUser) ||
              !context.categoryAvailable
            ) {
              return items;
            }
            return [
              {
                id: SUGGEST_ID,
                name: i18n("discourse_ai.ai_helper.choose"),
                icon: "discourse-sparkles",
                sticky: true,
                // Looked up on use: resolving them at boot would pin them before tests can stub them.
                onSelect: (select) =>
                  applyNewSuggestion(select, context, {
                    toasts: api.container.lookup("service:toasts"),
                    a11y: api.container.lookup("service:a11y"),
                  }),
              },
              ...items,
            ];
          });
          spec.row((row, { item }) => {
            if (item.id === SUGGEST_ID) {
              row.classes.push("ai-category-suggest-row");
            }
          });
        });
      }
    }
  );

  if (siteSettings.enable_new_select_controls) {
    return;
  }

  api.modifySelectKit("category-chooser").prependContent((component) => {
    const context = chooserSuggestionContext(component);
    if (!enabledFor(context, siteSettings, currentUser)) {
      return;
    }

    if (component.selectKit.filter) {
      return;
    }

    if (!stateFor(component).loading && context.categoryAvailable) {
      return triggerRow(component, context);
    }
  });
}

export default {
  name: "ai-category-chooser-inline-suggester",
  initialize() {
    withPluginApi(initInlineCategorySuggester);
  },
};
