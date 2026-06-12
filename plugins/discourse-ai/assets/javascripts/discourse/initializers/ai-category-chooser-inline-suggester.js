import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { MIN_CHARACTER_COUNT } from "../lib/ai-helper-suggestions";
import { showComposerAiHelper } from "../lib/show-ai-helper";

const SUGGEST_ID = "ai-category-suggest";
const EXIT_ID = "ai-category-exit";

const STATE = new WeakMap();

function stateFor(component) {
  let state = STATE.get(component);
  if (!state) {
    state = { mode: "idle", suggestions: [] };
    STATE.set(component, state);
  }
  return state;
}

function reset(component) {
  const state = stateFor(component);
  state.mode = "idle";
  state.suggestions = [];
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

async function loadSuggestions(component, selectKit) {
  const composer = getOwner(component).lookup("service:composer");
  const text = composer?.model?.reply;
  const state = stateFor(component);

  if (!text || text.length < MIN_CHARACTER_COUNT) {
    noSuggestionsToast(component);
    return;
  }

  state.mode = "loading";
  selectKit.triggerSearch();

  try {
    const { assistant } = await ajax(
      "/discourse-ai/ai-helper/suggest_category",
      { method: "POST", data: { text } }
    );

    if (component.isDestroying || component.isDestroyed) {
      return;
    }

    state.suggestions = assistant || [];
    state.mode = state.suggestions.length ? "results" : "idle";

    if (!state.suggestions.length) {
      noSuggestionsToast(component);
    }
  } catch (error) {
    state.mode = "idle";
    popupAjaxError(error);
  } finally {
    if (!component.isDestroying && !component.isDestroyed) {
      selectKit.triggerSearch();
    }
  }
}

function triggerRow(component) {
  return {
    id: SUGGEST_ID,
    label: `<span class="ai-category-suggest__label">${i18n(
      "discourse_ai.ai_helper.suggest"
    )}</span>${iconHTML("discourse-sparkles")}`,
    onSelect: (selectKit) => loadSuggestions(component, selectKit),
  };
}

function loadingRow() {
  return {
    id: SUGGEST_ID,
    label: `<span class="ai-category-loading__label">${i18n(
      "discourse_ai.ai_helper.context_menu.loading"
    )}</span>${iconHTML("spinner", { class: "fa-spin" })}`,
    onSelect: () => {},
  };
}

function exitRow(component) {
  return {
    id: EXIT_ID,
    label: `<span class="ai-category-exit__label">${i18n(
      "discourse_ai.ai_helper.suggestions"
    )}</span>${iconHTML("xmark")}`,
    onSelect: (selectKit) => {
      reset(component);
      selectKit.triggerSearch();
    },
  };
}

function enabledFor(component, siteSettings, currentUser) {
  const composer = getOwner(component).lookup("service:composer");
  return (
    siteSettings.ai_embeddings_enabled &&
    composer?.model &&
    showComposerAiHelper(
      composer.model,
      siteSettings,
      currentUser,
      "suggestions"
    )
  );
}

function hasEnoughContent(component) {
  const composer = getOwner(component).lookup("service:composer");
  return (composer?.model?.reply?.length ?? 0) > MIN_CHARACTER_COUNT;
}

function initInlineCategorySuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifySelectKit("category-chooser").prependContent((component) => {
    if (!enabledFor(component, siteSettings, currentUser)) {
      return;
    }

    if (component.selectKit.filter) {
      reset(component);
      return;
    }

    if (stateFor(component).mode === "idle" && hasEnoughContent(component)) {
      return triggerRow(component);
    }
  });

  api.modifySelectKit("category-chooser").replaceContent((component) => {
    if (!enabledFor(component, siteSettings, currentUser)) {
      return;
    }

    if (component.selectKit.filter) {
      return;
    }

    const state = stateFor(component);

    if (state.mode === "loading") {
      return [loadingRow()];
    }

    if (state.mode === "results") {
      return [
        exitRow(component),
        ...state.suggestions.map((s) => ({ id: s.id, name: s.name })),
      ];
    }
  });

  api.modifySelectKit("category-chooser").onChange((component, value) => {
    if (value !== SUGGEST_ID && value !== EXIT_ID) {
      reset(component);
    }
  });
}

export default {
  name: "ai-category-chooser-inline-suggester",
  initialize() {
    withPluginApi(initInlineCategorySuggester);
  },
};
