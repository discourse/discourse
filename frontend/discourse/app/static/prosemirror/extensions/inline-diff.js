// @ts-check
import { recreateTransform } from "@fellow/prosemirror-recreate-transform";
import { ChangeSet } from "prosemirror-changeset";
import { isTesting } from "discourse/lib/environment";
import { iconElement } from "discourse/lib/icon-library";
import {
  findChangeByCoords,
  fragmentHasVisibleContent,
  sliceIsBlockLevel,
} from "discourse/static/prosemirror/lib/inline-diff-fragment";
import { i18n } from "discourse-i18n";

const REVERT_ICON = "arrow-rotate-left";

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  plugins(args) {
    return createInlineDiffPlugin(args);
  },

  commands() {
    return {
      toggleInlineDiff: (enabled) => (state, dispatch) => {
        dispatch?.(state.tr.setMeta(META.ENABLE, enabled));
        return true;
      },
    };
  },
};

export default extension;

// ============================================================================
// Constants
// ============================================================================

// Meta keys that drive plugin state transitions.
const META = Object.freeze({
  ENABLE: "inline-diff-enabled",
  REFRESH_ORIGINAL: "inline-diff-refresh-original",
});

// App events we listen on. `composer:reply-reloaded` fires after the composer
// model's post-fetch promise resolves (e.g. draft restore), which is when a
// newly-available `originalRaw` needs to be picked up.
const EVENTS = Object.freeze({
  REPLY_RELOADED: "composer:reply-reloaded",
});

// CSS classes, kept in one place so they stay in sync with rich-editor.scss.
const CSS = Object.freeze({
  ADDED: "diff-added",
  DELETED: "diff-deleted",
  DELETED_NODE: "diff-deleted-node",
  REVERT: "diff-revert-button",
  REVERT_INLINE: "diff-revert-button--inline",
});

// Single `data` tag for every `addSteps` call so that changeset's default
// `combine` function (`(a, b) => a === b ? a : null`) merges adjacent
// changes. Without a consistent tag, one logical edit fragments into a
// separate `Change` per step map → one revert button per step map.
const CHANGE_TAG = "diff";

// PM decoration anchoring: a widget with `SIDE_BEFORE` sits before the anchor
// position (left-associative), `SIDE_AFTER` sits after it. We use BEFORE for
// deleted-content widgets (so they render just ahead of the inserted content)
// and AFTER for standalone revert buttons (right of the change).
const SIDE_BEFORE = -1;
const SIDE_AFTER = 1;

// ============================================================================
// Plugin factory
// ============================================================================

function createInlineDiffPlugin({
  pmState: { Plugin, PluginKey },
  pmView: { Decoration, DecorationSet },
  pmModel: { DOMSerializer },
  schema,
  getContext,
  utils: { convertFromMarkdown },
}) {
  const pluginKey = new PluginKey("inline-diff");
  const domSerializer = DOMSerializer.fromSchema(schema);

  // ==========================================================================
  // State helpers
  // ==========================================================================

  function pluginState({
    enabled = false,
    originalDoc = null,
    changeset = null,
    decorations = DecorationSet.empty,
  } = {}) {
    return { enabled, originalDoc, changeset, decorations };
  }

  function originalDocFromContext() {
    const raw = getContext().originalRaw;
    return raw ? convertFromMarkdown(raw) : null;
  }

  // Shortcut for the common "enabled + changeset" return: builds decorations
  // from the changeset and packages everything up. Called in both the
  // bootstrap path and the live-step path.
  function stateWithChangeset(enabled, originalDoc, changeset, newDoc) {
    return pluginState({
      enabled,
      originalDoc,
      changeset,
      decorations: buildDecorations(changeset, originalDoc, newDoc),
    });
  }

  // Wraps a state-producing fn with a try/catch that either re-throws in test
  // (so failures aren't swallowed) or logs + returns `fallback()` in
  // production. Fallback is a thunk so expensive recoveries (rebuilding the
  // changeset) aren't paid on the happy path.
  function safeCompute(fn, fallback, warnMessage) {
    try {
      return fn();
    } catch (e) {
      if (isTesting()) {
        throw e;
      }
      // eslint-disable-next-line no-console
      console.warn(`inline-diff: ${warnMessage}`, e);
      return fallback();
    }
  }

  // ==========================================================================
  // DOM builders
  // ==========================================================================

  // A revert button's four coordinates are stored as `data-*` attrs and are
  // its *stable identity*: they match the widget's decoration `key`, so PM
  // only reuses the DOM when all four still match the current decoration
  // spec. That's what keeps `findChangeForButton` honest across widget-DOM
  // reuse.
  function deletedNodeId(change) {
    return `diff-deleted-${change.fromA}-${change.toA}-${change.fromB}-${change.toB}`;
  }

  function createRevertButton(change, { describedBy } = {}) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = CSS.REVERT;
    btn.setAttribute("aria-label", i18n("composer.diff_revert"));
    btn.setAttribute("contenteditable", "false");
    if (describedBy) {
      btn.setAttribute("aria-describedby", describedBy);
    }
    btn.tabIndex = 0;
    btn.dataset.fromA = String(change.fromA);
    btn.dataset.toA = String(change.toA);
    btn.dataset.fromB = String(change.fromB);
    btn.dataset.toB = String(change.toB);
    btn.appendChild(iconElement(REVERT_ICON));
    return btn;
  }

  // Render a slice of the original doc (change.fromA..change.toA) as a block
  // or inline DOM wrapper. For block wrappers we inline the revert button so
  // the CSS can absolute-position it against `.diff-deleted-node`; for inline
  // wrappers a standalone button is added elsewhere.
  function createDeletedWidget(change, isBlock, originalDoc) {
    const fragment = originalDoc.slice(change.fromA, change.toA).content;
    const wrapper = document.createElement(isBlock ? "div" : "span");
    wrapper.className = isBlock ? CSS.DELETED_NODE : CSS.DELETED;
    wrapper.id = deletedNodeId(change);
    wrapper.appendChild(domSerializer.serializeFragment(fragment));

    if (isBlock) {
      wrapper.appendChild(
        createRevertButton(change, { describedBy: wrapper.id })
      );
    }
    return wrapper;
  }

  // ==========================================================================
  // Revert handling
  // ==========================================================================

  function findChangeForButton(view, btn) {
    const { changeset } = pluginKey.getState(view.state);
    return findChangeByCoords(changeset?.changes, {
      fromA: Number(btn.dataset.fromA),
      toA: Number(btn.dataset.toA),
      fromB: Number(btn.dataset.fromB),
      toB: Number(btn.dataset.toB),
    });
  }

  function revertChange(view, originalDoc, change) {
    const slice = originalDoc.slice(change.fromA, change.toA);
    view.dispatch(view.state.tr.replace(change.fromB, change.toB, slice));
  }

  function handleRevertEvent(view, event) {
    const btn = event.target?.closest?.(`.${CSS.REVERT}`);
    if (!btn) {
      return false;
    }

    const state = pluginKey.getState(view.state);
    if (!state?.originalDoc) {
      // Plugin not ready — let PM handle the click normally.
      return false;
    }

    const change = findChangeForButton(view, btn);
    if (!change) {
      // Stale widget DOM briefly present across a transaction — don't
      // swallow the event.
      return false;
    }

    event.preventDefault();
    revertChange(view, state.originalDoc, change);
    view.focus();
    return true;
  }

  // Only Enter / Space activate a focused revert button via keyboard; any
  // other key is normal typing and must pass through to PM.
  function handleRevertKeydown(view, event) {
    if (event.key !== "Enter" && event.key !== " ") {
      return false;
    }
    return handleRevertEvent(view, event);
  }

  // ==========================================================================
  // Decoration building
  // ==========================================================================

  function decorationKey(prefix, change) {
    return `${prefix}-${change.fromA}-${change.toA}-${change.fromB}-${change.toB}`;
  }

  function addInsertedDecoration(decorations, change) {
    decorations.push(
      Decoration.inline(change.fromB, change.toB, { class: CSS.ADDED })
    );
  }

  function addDeletedDecoration(
    decorations,
    change,
    deletedIsBlock,
    originalDoc
  ) {
    // Lazy factory: PM only calls it when no widget with our `key` already
    // exists. Serializing the deleted fragment on every transaction (via an
    // eager build + cloneNode) was wasted work on key matches.
    decorations.push(
      Decoration.widget(
        change.fromB,
        () => createDeletedWidget(change, deletedIsBlock, originalDoc),
        {
          side: SIDE_BEFORE,
          key: decorationKey("del", change),
          ignoreSelection: true,
        }
      )
    );
  }

  function addStandaloneRevertButton(decorations, change, hasDeletedWrapper) {
    // Used when no `.diff-deleted-node` wrapper exists to host the button
    // inline (inline-only changes, or pure insertions). Anchor at `toB`: for
    // inserts that's just after the added content; for pure deletes toB and
    // fromB coincide.
    decorations.push(
      Decoration.widget(
        change.toB,
        () => {
          const btn = createRevertButton(change, {
            describedBy: hasDeletedWrapper ? deletedNodeId(change) : undefined,
          });
          btn.classList.add(CSS.REVERT_INLINE);
          return btn;
        },
        {
          side: SIDE_AFTER,
          key: decorationKey("rev", change),
          ignoreSelection: true,
        }
      )
    );
  }

  function buildDecorations(changeset, originalDoc, currentDoc) {
    const decorations = [];

    for (const change of changeset.changes) {
      const deletedFragment =
        change.fromA < change.toA
          ? originalDoc.slice(change.fromA, change.toA).content
          : null;
      const insertedFragment =
        change.fromB < change.toB
          ? currentDoc.slice(change.fromB, change.toB).content
          : null;

      // Skip changes whose PM ranges are non-zero but visually empty (e.g.
      // a splitBlock step that only moves a boundary). Without this guard
      // we'd render orphan revert buttons and empty strike bars.
      const hasDeleted = fragmentHasVisibleContent(deletedFragment);
      const hasInserted = fragmentHasVisibleContent(insertedFragment);
      if (!hasDeleted && !hasInserted) {
        continue;
      }

      // Block-ness is computed on the deleted side only — it's what picks
      // between a block wrapper (with an embedded revert button) and an
      // inline strike. Forcing both sides to the same bucket made tiny
      // inline deletions ("e!") render as full-width pink bars when they
      // happened to sit next to a block insertion.
      const deletedIsBlock = hasDeleted && sliceIsBlockLevel(deletedFragment);

      if (hasInserted) {
        addInsertedDecoration(decorations, change);
      }
      if (hasDeleted) {
        addDeletedDecoration(decorations, change, deletedIsBlock, originalDoc);
      }
      // The deleted-block wrapper already hosts a revert button inside it;
      // otherwise we need a standalone one.
      if (!deletedIsBlock) {
        addStandaloneRevertButton(decorations, change, hasDeleted);
      }
    }

    return DecorationSet.create(currentDoc, decorations);
  }

  // ==========================================================================
  // Changeset bootstrap
  // ==========================================================================

  function bootstrapChangeset(originalDoc, currentDoc) {
    let cs = ChangeSet.create(originalDoc);
    if (originalDoc.eq(currentDoc)) {
      return cs;
    }

    return safeCompute(
      () => {
        // wordDiffs keeps text edits at word granularity — char-level
        // produces noisy per-letter changes.
        const tr = recreateTransform(originalDoc, currentDoc, {
          complexSteps: true,
          wordDiffs: true,
          simplifyDiff: true,
        });
        // addSteps(newDoc, maps, data) — note `maps`, not `steps`.
        return cs.addSteps(tr.doc, tr.mapping.maps, CHANGE_TAG);
      },
      () => cs,
      "recreateTransform failed"
    );
  }

  // ==========================================================================
  // Plugin
  // ==========================================================================

  return new Plugin({
    key: pluginKey,

    state: {
      init() {
        // Don't eagerly load originalDoc — apply() handles it the first time
        // diff is enabled. Skipping the init-time convertFromMarkdown means
        // composers that never toggle diff pay nothing.
        return pluginState();
      },

      apply(tr, prev, _oldState, newState) {
        const meta = tr.getMeta(META.ENABLE);
        const refresh = tr.getMeta(META.REFRESH_ORIGINAL);
        let { enabled, originalDoc, changeset } = prev;

        if (meta !== undefined) {
          enabled = meta;
        }

        // Load originalDoc on first need, or refresh it when post.raw changes
        // (draft restore fires composer:reply-reloaded → REFRESH_ORIGINAL).
        if ((enabled && !originalDoc) || refresh) {
          const next = originalDocFromContext();
          if (next) {
            originalDoc = next;
            changeset = null; // rebuild against the fresh original
          }
        }

        if (!enabled || !originalDoc) {
          return pluginState({ enabled, originalDoc });
        }

        // First enable (or originalDoc just appeared): bootstrap changeset.
        if (!changeset) {
          const built = safeCompute(
            () => bootstrapChangeset(originalDoc, newState.doc),
            () => null,
            "bootstrap failed"
          );
          return built
            ? stateWithChangeset(enabled, originalDoc, built, newState.doc)
            : pluginState({ enabled, originalDoc });
        }

        // Record this transaction's steps into the changeset.
        if (tr.docChanged) {
          const next = safeCompute(
            () => changeset.addSteps(newState.doc, tr.mapping.maps, CHANGE_TAG),
            () => bootstrapChangeset(originalDoc, newState.doc),
            "addSteps failed; rebuilding changeset"
          );
          return stateWithChangeset(enabled, originalDoc, next, newState.doc);
        }

        // No doc change — positions are stable, keep decorations as-is.
        return pluginState({
          enabled,
          originalDoc,
          changeset,
          decorations: prev.decorations,
        });
      },
    },

    view(view) {
      const appEvents = getContext().appEvents;
      const onReplyReloaded = () => {
        view.dispatch(view.state.tr.setMeta(META.REFRESH_ORIGINAL, true));
      };
      appEvents?.on(EVENTS.REPLY_RELOADED, onReplyReloaded);

      // Deferred enable: the composer can mount us with inline-diff already
      // requested (e.g. the markdown→rich switch after a dialog confirm).
      // Dispatching synchronously inside `view()` races with PM's own
      // initialization; microtask gives PM time to finish wiring up.
      if (getContext().inlineDiffEnabled) {
        queueMicrotask(() => {
          if (!pluginKey.getState(view.state)?.enabled) {
            view.dispatch(view.state.tr.setMeta(META.ENABLE, true));
          }
        });
      }

      return {
        destroy() {
          appEvents?.off(EVENTS.REPLY_RELOADED, onReplyReloaded);
        },
      };
    },

    props: {
      decorations(state) {
        return pluginKey.getState(state).decorations;
      },

      handleDOMEvents: {
        // `mousedown` preempts PM's selection handling for pointer activation;
        // `keydown` covers Enter / Space on the focused button.
        mousedown: handleRevertEvent,
        keydown: handleRevertKeydown,
      },
    },
  });
}
