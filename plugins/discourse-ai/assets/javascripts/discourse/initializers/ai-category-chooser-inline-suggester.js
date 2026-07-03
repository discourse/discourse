import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { chooserSuggestionContext } from "../lib/chooser-suggestion-context";
import { showComposerAiHelper } from "../lib/show-ai-helper";

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

    if (component.isDestroying || component.isDestroyed) {
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
    if (!component.isDestroying && !component.isDestroyed) {
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

function initInlineCategorySuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifySelectKit("category-chooser").prependContent((component) => {
    const context = chooserSuggestionContext(component);
    if (!enabledFor(context, siteSettings, currentUser)) {
      return;
    }

    if (component.selectKit.filter) {
      return;
    }

    if (!stateFor(component).loading && context.available) {
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
