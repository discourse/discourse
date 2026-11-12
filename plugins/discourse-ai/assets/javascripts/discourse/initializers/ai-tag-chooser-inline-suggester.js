import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import {
  chooserSuggestionContext,
  chooserSuggestionContextFromInstance,
} from "../lib/chooser-suggestion-context.js";
import { showComposerAiHelper } from "../lib/show-ai-helper.js";

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

async function loadSuggestions(component, selectKit, context) {
  const state = stateFor(component);
  const data = context.tagRequestData();

  if (!data) {
    noSuggestionsToast(component);
    return;
  }

  state.mode = "loading";
  selectKit.triggerSearch();

  try {
    const { assistant } = await ajax("/discourse-ai/ai-helper/suggest_tags", {
      method: "POST",
      data,
    });

    if (component.isDestroying) {
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
    if (!component.isDestroying) {
      selectKit.triggerSearch();
    }
  }
}

function triggerRow(component, context) {
  return {
    id: SUGGEST_ID,
    name: i18n("discourse_ai.ai_helper.suggest"),
    icon: "discourse-sparkles",
    classNames: "ai-tag-suggest-row",
    onSelect: (selectKit) => loadSuggestions(component, selectKit, context),
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

function enabledFor(context, siteSettings, currentUser) {
  return (
    !!context &&
    siteSettings.ai_embeddings_enabled &&
    context.tagChooserEnabled &&
    showComposerAiHelper(
      context.model,
      siteSettings,
      currentUser,
      "suggestions"
    )
  );
}

function initInlineTagSuggester(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("service:site-settings");
  const toasts = api.container.lookup("service:toasts");

  api.registerValueTransformer(
    "select-customizations",
    ({ value: selects }) => {
      for (const identifier of ["composer-tags", "topic-edit-tags"]) {
        selects.forIdentifier(identifier, (spec) => {
          // `suggestions` caches one suggesting session's results.
          const state = trackedObject({ suggesting: false, suggestions: null });

          const stopSuggesting = () => {
            state.suggesting = false;
            state.suggestions = null;
          };

          spec.load((load, { filter, instanceContext }) => {
            const context =
              chooserSuggestionContextFromInstance(instanceContext);
            if (filter || !enabledFor(context, siteSettings, currentUser)) {
              stopSuggesting();
            }
            if (!state.suggesting) {
              return load;
            }
            // Cached suggestions answer synchronously, so reopening the list while suggesting
            // neither asks the AI again nor shows a loading state.
            if (state.suggestions) {
              return () => state.suggestions;
            }
            return async (query, opts) => {
              const data = context.tagRequestData();
              if (!data) {
                stopSuggesting();
                return load(query, opts);
              }
              state.suggestions =
                (
                  await ajax("/discourse-ai/ai-helper/suggest_tags", {
                    method: "POST",
                    data,
                    signal: opts?.signal,
                  })
                ).assistant ?? [];
              if (!state.suggestions.length) {
                toasts.error({
                  duration: "short",
                  data: {
                    message: i18n(
                      "discourse_ai.ai_helper.suggest_errors.no_suggestions"
                    ),
                  },
                });
                stopSuggesting();
                return load(query, opts);
              }
              return state.suggestions;
            };
          });

          spec.content((options, { filter, instanceContext }) => {
            const context =
              chooserSuggestionContextFromInstance(instanceContext);
            if (filter || !enabledFor(context, siteSettings, currentUser)) {
              return options;
            }
            if (state.suggesting) {
              // Held tags leave the suggestions as they are picked, and return when removed.
              const held = context.selectedTagNames;
              return [
                selectOption(
                  {
                    id: EXIT_ID,
                    icon: "xmark",
                    name: i18n("discourse_ai.ai_helper.suggestions"),
                  },
                  {
                    position: "sticky",
                    onSelect(control) {
                      stopSuggesting();
                      control.reload({ immediate: true });
                    },
                  }
                ),
                ...options.filter(({ record }) => !held.includes(record.name)),
              ];
            }
            if (!context.available) {
              return options;
            }
            return [
              selectOption(
                {
                  id: SUGGEST_ID,
                  icon: "discourse-sparkles",
                  name: i18n("discourse_ai.ai_helper.suggest"),
                },
                {
                  position: "sticky",
                  onSelect(control) {
                    state.suggesting = true;
                    control.reload({ immediate: true });
                  },
                }
              ),
              ...options,
            ];
          });

          spec.config(() =>
            state.suggesting
              ? {
                  loadingStatus: true,
                  texts: {
                    loadingLabel: i18n(
                      "discourse_ai.ai_helper.context_menu.loading"
                    ),
                  },
                }
              : {}
          );

          spec.optionAttributes((attributes, { record }) => {
            if (record.id === SUGGEST_ID || record.id === EXIT_ID) {
              attributes.classes.push(
                record.id === EXIT_ID ? "ai-tag-exit-row" : "ai-tag-suggest-row"
              );
            }
          });
        });
      }
    }
  );

  api
    .modifySelectKit("mini-tag-chooser", { bridge: false })
    .prependContent((component) => {
      const context = chooserSuggestionContext(component);
      if (!enabledFor(context, siteSettings, currentUser)) {
        return;
      }

      if (component.selectKit.filter) {
        reset(component);
        return;
      }

      if (stateFor(component).mode === "idle" && context.available) {
        return triggerRow(component, context);
      }
    });

  api
    .modifySelectKit("mini-tag-chooser", { bridge: false })
    .replaceContent((component) => {
      const context = chooserSuggestionContext(component);
      if (!enabledFor(context, siteSettings, currentUser)) {
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
        const taken = context.selectedTagNames;
        const remaining = state.suggestions.filter(
          (s) => !taken.includes(s.name)
        );
        return [
          exitRow(component),
          ...remaining.map((s) => ({
            id: s.name,
            name: s.name,
            count: s.count,
          })),
        ];
      }
    });

  api
    .modifySelectKit("mini-tag-chooser", { bridge: false })
    .onChange((component) => {
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
