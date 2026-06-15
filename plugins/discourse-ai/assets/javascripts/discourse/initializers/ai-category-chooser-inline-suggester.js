import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { MIN_CHARACTER_COUNT } from "../lib/ai-helper-suggestions";
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

function composerFor(component) {
  return getOwner(component).lookup("service:composer");
}

// only attach to the composer's own chooser, not every category-chooser
// elsewhere in the app while a draft happens to be open
function inComposer(component) {
  return !!component.element?.closest("#reply-control");
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

async function applyBestSuggestion(component, selectKit) {
  const composer = composerFor(component);
  const text = composer?.model?.reply;
  const state = stateFor(component);

  if (!text || text.length < MIN_CHARACTER_COUNT) {
    noSuggestionsToast(component);
    return;
  }

  const startCategoryId = composer.model.categoryId;
  state.loading = true;
  selectKit.close();
  selectKit.set("isLoading", true);

  try {
    const { assistant } = await ajax(
      "/discourse-ai/ai-helper/suggest_category",
      { method: "POST", data: { text } }
    );

    if (component.isDestroying || component.isDestroyed) {
      return;
    }

    if (composer.model.categoryId !== startCategoryId) {
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

function triggerRow(component) {
  return {
    id: SUGGEST_ID,
    name: i18n("discourse_ai.ai_helper.choose"),
    icon: "discourse-sparkles",
    classNames: "ai-category-suggest-row",
    onSelect: (selectKit) => applyBestSuggestion(component, selectKit),
  };
}

function enabledFor(component, siteSettings, currentUser) {
  const composer = composerFor(component);
  return (
    siteSettings.ai_embeddings_enabled &&
    composer?.model &&
    !composer.disableCategoryChooser &&
    inComposer(component) &&
    showComposerAiHelper(
      composer.model,
      siteSettings,
      currentUser,
      "suggestions"
    )
  );
}

function hasEnoughContent(component) {
  return (
    (composerFor(component)?.model?.reply?.length ?? 0) > MIN_CHARACTER_COUNT
  );
}

function initInlineCategorySuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifySelectKit("category-chooser").prependContent((component) => {
    if (!enabledFor(component, siteSettings, currentUser)) {
      return;
    }

    if (component.selectKit.filter) {
      return;
    }

    if (!stateFor(component).loading && hasEnoughContent(component)) {
      return triggerRow(component);
    }
  });
}

export default {
  name: "ai-category-chooser-inline-suggester",
  initialize() {
    withPluginApi(initInlineCategorySuggester);
  },
};
