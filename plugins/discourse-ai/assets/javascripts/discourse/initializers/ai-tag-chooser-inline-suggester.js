import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import {
  MIN_CHARACTER_COUNT,
  tagSuggestionParams,
} from "../lib/ai-helper-suggestions";
import { showComposerAiHelper } from "../lib/show-ai-helper";

const SUGGEST_ID = "ai-tag-suggest";
const EXIT_ID = "ai-tag-exit";

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

function composerFor(component) {
  return getOwner(component).lookup("service:composer");
}

// only attach to the composer's own chooser, not every mini-tag-chooser
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

function selectedTagNames(component) {
  const tags = composerFor(component)?.model?.tags ?? [];
  return tags.map((t) => (typeof t === "string" ? t : t.name));
}

async function loadSuggestions(component, selectKit) {
  const composer = composerFor(component);
  const model = composer?.model;
  const text = model?.reply;
  const state = stateFor(component);

  if (!text || text.length < MIN_CHARACTER_COUNT) {
    noSuggestionsToast(component);
    return;
  }

  state.mode = "loading";
  selectKit.triggerSearch();

  try {
    const { assistant } = await ajax("/discourse-ai/ai-helper/suggest_tags", {
      method: "POST",
      data: { text, ...tagSuggestionParams(model.categoryId, model.tags) },
    });

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
    name: i18n("discourse_ai.ai_helper.suggest"),
    icon: "discourse-sparkles",
    classNames: "ai-tag-suggest-row",
    onSelect: (selectKit) => loadSuggestions(component, selectKit),
  };
}

function loadingRow() {
  return {
    id: SUGGEST_ID,
    name: i18n("discourse_ai.ai_helper.context_menu.loading"),
    icon: "spinner",
    classNames: "ai-tag-suggest-row",
    onSelect: () => {},
  };
}

function exitRow(component) {
  return {
    id: EXIT_ID,
    name: i18n("discourse_ai.ai_helper.suggestions"),
    icon: "xmark",
    classNames: "ai-tag-exit-row",
    onSelect: (selectKit) => {
      reset(component);
      selectKit.triggerSearch();
    },
  };
}

function enabledFor(component, siteSettings, currentUser) {
  const composer = composerFor(component);
  return (
    siteSettings.ai_embeddings_enabled &&
    composer?.model &&
    !composer.disableTagsChooser &&
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

function initInlineTagSuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");

  api.modifySelectKit("mini-tag-chooser").prependContent((component) => {
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

  api.modifySelectKit("mini-tag-chooser").replaceContent((component) => {
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
      const taken = selectedTagNames(component);
      const remaining = state.suggestions.filter(
        (s) => !taken.includes(s.name)
      );
      return [
        exitRow(component),
        ...remaining.map((s) => ({ id: s.name, name: s.name, count: s.count })),
      ];
    }
  });

  api.modifySelectKit("mini-tag-chooser").onChange((component) => {
    if (stateFor(component).mode === "results") {
      component.selectKit.triggerSearch();
    }
  });
}

export default {
  name: "ai-tag-chooser-inline-suggester",
  initialize() {
    withPluginApi(initInlineTagSuggester);
  },
};
