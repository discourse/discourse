// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import {
  SCHEMAS,
  toDoc,
  toStorage,
} from "discourse/plugins/discourse-visual-editor/discourse/lib/inline-rich-text";

/**
 * Mounts a ProseMirror editor over the currently-edited inline text region
 * and exposes its commands to the block-toolbar.
 *
 * Watches `visualEditor.editingBlockKey` + `editingArgName`. When set, it
 * locates the matching renderer span via a DOM query against the canvas
 * (`[data-ve-block-key="..."] [data-ve-inline-edit-arg="..."]`), reads the
 * schema variant off `data-ve-inline-edit-schema`, and mounts a constrained
 * PM editor into the span via `{{in-element insertBefore=null}}`. PM is the
 * source of truth during the session — `args.text` is written once at
 * commit time, not per keystroke.
 *
 * The bold / italic / link UI lives in `block-toolbar.gjs` (shared with the
 * block move/duplicate/delete buttons). The block-toolbar reaches this
 * controller via `visualEditor.inlineEditor` and calls its public methods
 * (`toggleMark`, `enterLinkMode`, etc.); a tracked `_pmStateVersion`
 * counter bumps on every PM transaction so the toolbar's `markState`
 * getter (which depends on PM state) re-evaluates reactively.
 *
 * ProseMirror modules are lazy-loaded the first time the user enters an
 * edit session — see `discourse/lib/load-inline-rich-editor`.
 */
export default class InlineEditController extends Component {
  @service visualEditor;

  /**
   * Inline link-edit mode — when `true`, the block-toolbar swaps its
   * inline-format buttons for a URL input + Apply / Remove / Cancel.
   * Template-facing (the block-toolbar reads it through
   * `visualEditor.inlineEditor.linkEditMode`).
   */
  @tracked linkEditMode = false;
  /** Live value of the URL input while in link-edit mode. */
  @tracked linkEditUrl = "";
  #view = null;
  #pm = null;
  #handleOutsideClick = null;
  #editingRendererEl = null;
  #savedLinkRange = null;
  /**
   * Tracked counter bumped on every PM transaction. Read by
   * `markState` / `selectionEmpty` getters to participate in Glimmer's
   * autotracking — PM state itself isn't tracked, so without this bump
   * the toolbar's active-mark buttons would never re-render.
   *
   * Underscored because nothing in a template binds to it directly;
   * consumers read the getters that depend on it.
   */
  @tracked _pmStateVersion = 0;

  constructor() {
    super(...arguments);
    this.visualEditor.registerInlineEditor(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.visualEditor.unregisterInlineEditor(this);
  }

  /**
   * The renderer span the editor should mount into, looked up off the
   * service's `(editingBlockKey, editingArgName)`. Returns `null` when no
   * session is active or when the renderer hasn't rendered yet (the canvas
   * may be in the middle of swapping blocks).
   *
   * @returns {HTMLElement | null}
   */
  @cached
  get activeRendererEl() {
    const { editingBlockKey, editingArgName } = this.visualEditor;
    if (!editingBlockKey || !editingArgName) {
      return null;
    }
    const blockSelector = `[data-ve-block-key="${cssEscape(editingBlockKey)}"]`;
    const argSelector = `[data-ve-inline-edit-arg="${cssEscape(editingArgName)}"]`;
    return document.querySelector(`${blockSelector} ${argSelector}`);
  }

  /**
   * Schema variant emitted by the renderer (`plain`/`heading`/`paragraph`).
   * Falls back to `plain` so the editor always mounts with *some* schema
   * even if the data-attr is missing.
   *
   * @returns {"plain"|"heading"|"paragraph"}
   */
  get schemaName() {
    const el = this.activeRendererEl;
    const raw = el?.dataset?.veInlineEditSchema;
    return raw && raw in SCHEMAS ? raw : "plain";
  }

  /**
   * Public API consumed by `block-toolbar.gjs`. Returns the
   * active-mark flags for the current PM selection, or `null` when the
   * inline-format buttons should be hidden (no view, empty selection,
   * or schema that doesn't allow marks).
   *
   * `@cached` + reading `_pmStateVersion` makes this reactive to PM
   * transactions without making PM's state itself tracked.
   *
   * @returns {{strong: boolean, em: boolean, link: boolean} | null}
   */
  @cached
  get markState() {
    // eslint-disable-next-line no-unused-vars
    const _v = this._pmStateVersion;
    const view = this.#view;
    if (!view) {
      return null;
    }
    const variant = SCHEMAS[this.schemaName];
    if (!variant?.allowsMarks) {
      return null;
    }
    const { empty } = view.state.selection;
    if (empty) {
      return null;
    }
    const { schema } = view.state;
    return {
      strong: hasMark(view.state, schema.marks.strong),
      em: hasMark(view.state, schema.marks.em),
      link: hasMark(view.state, schema.marks.link),
    };
  }

  @action
  async mountEditor(container) {
    const rendererEl = this.activeRendererEl;
    if (!rendererEl) {
      return;
    }
    this.#editingRendererEl = rendererEl;

    const pm = await loadInlineRichEditor();

    if (this.activeRendererEl !== rendererEl) {
      return;
    }

    this.#pm = pm;
    rendererEl.classList.add("--editing");

    const variant = SCHEMAS[this.schemaName];
    const schema = pm.createSchema(variant.extensions, false);
    const doc = pm.Node.fromJSON(
      schema,
      toDoc(this.visualEditor.editingArgValue)
    );

    const plugins = [
      pm.history(),
      pm.keymap({
        "Mod-z": pm.undo,
        "Mod-y": pm.redo,
        "Shift-Mod-z": pm.redo,
        ...(variant.allowsMarks && {
          "Mod-b": pm.toggleMark(schema.marks.strong),
          "Mod-i": pm.toggleMark(schema.marks.em),
        }),
        Escape: () => {
          this.visualEditor.stopEditing({ commit: true });
          return true;
        },
        // In a paragraph schema Enter inserts a hard_break; everywhere else
        // (heading, plain) Enter commits + exits. Phase 3 will change this
        // for paragraph to split into a new sibling block instead.
        Enter:
          this.schemaName === "paragraph" && variant.allowsHardBreak
            ? insertHardBreak(schema)
            : () => {
                this.visualEditor.stopEditing({ commit: true });
                return true;
              },
        // Tab walks between rich-inline fields on the same block in DOM
        // order. The service's `startEditingArg` implicitly commits the
        // current session, so chaining Tabs across fields produces one
        // undo entry per visited field. At the first / last field the
        // command returns false so the browser's default Tab handling
        // kicks in and focus leaves the editor naturally.
        Tab: this.#tabToSiblingArg(1),
        "Shift-Tab": this.#tabToSiblingArg(-1),
      }),
    ];

    this.#view = new pm.EditorView(container, {
      state: pm.EditorState.create({ schema, doc, plugins }),
      attributes: { class: "ve-inline-editor" },
      dispatchTransaction: (tr) => {
        const view = this.#view;
        if (!view) {
          return;
        }
        view.updateState(view.state.apply(tr));
        // Bump tracked counter so consumers reading PM-derived getters
        // (`markState`) re-evaluate. PM's state isn't itself tracked by
        // Glimmer; this is the bridge.
        this._pmStateVersion++;
      },
    });

    this.visualEditor.registerInlineEditCommit(() => {
      const finalView = this.#view;
      if (!finalView) {
        return;
      }
      const docJson = finalView.state.doc.toJSON();
      this.visualEditor.applyInlineEditChange(toStorage(docJson));
    });

    // Select all on entry — "start typing to replace" affordance for the
    // most common edit case (replacing existing text).
    const allRange = pm.TextSelection.create(
      this.#view.state.doc,
      0,
      this.#view.state.doc.content.size
    );
    this.#view.dispatch(this.#view.state.tr.setSelection(allRange));
    this.#view.focus();

    this.#handleOutsideClick = (event) => {
      if (!this.#view || this.#view.dom.contains(event.target)) {
        return;
      }
      // The block-toolbar (which now hosts the inline-format buttons) sits
      // outside view.dom but is functionally part of the editor. Treat
      // clicks inside any block-toolbar as inside the editor so the
      // session doesn't exit when applying a mark.
      if (event.target.closest?.(".visual-editor-block-toolbar")) {
        return;
      }
      const myEl = this.#editingRendererEl;
      requestAnimationFrame(() => {
        if (this.activeRendererEl === myEl) {
          this.visualEditor.stopEditing({ commit: true });
        }
      });
    };
    document.addEventListener("mousedown", this.#handleOutsideClick, true);
  }

  @action
  unmountEditor() {
    this.visualEditor.registerInlineEditCommit(null);

    const view = this.#view;
    this.#view = null;
    if (view) {
      view.destroy();
    }
    if (this.#handleOutsideClick) {
      document.removeEventListener("mousedown", this.#handleOutsideClick, true);
      this.#handleOutsideClick = null;
    }
    this.#editingRendererEl?.classList.remove("--editing");
    this.#editingRendererEl = null;
    this.#savedLinkRange = null;
    this.linkEditMode = false;
    this.linkEditUrl = "";
    // Force a re-evaluation of `markState` so the toolbar hides cleanly.
    this._pmStateVersion++;
  }

  /**
   * Toggles `strong` or `em` over the current PM selection. Called by
   * the block-toolbar's inline-format buttons (via
   * `visualEditor.inlineEditor.toggleMark`).
   *
   * Explicitly re-sets the selection on the transaction so PM re-renders
   * the DOM selection highlight after dispatch — without this, focus
   * loss from clicking a button outside PM can leave the user with no
   * visible selection even though the model selection survived.
   *
   * @param {"strong" | "em"} markName
   */
  @action
  toggleMark(markName) {
    const view = this.#view;
    if (!view) {
      return;
    }
    const markType = view.state.schema.marks[markName];
    if (!markType) {
      return;
    }
    const { from, to } = view.state.selection;
    if (from === to) {
      return;
    }
    const tr = view.state.tr;
    if (view.state.doc.rangeHasMark(from, to, markType)) {
      tr.removeMark(from, to, markType);
    } else {
      tr.addMark(from, to, markType.create());
    }
    tr.setSelection(this.#pm.TextSelection.create(tr.doc, from, to));
    view.dispatch(tr);
    view.focus();
  }

  /**
   * Transitions the toolbar into link-edit mode (URL input visible) for
   * the current non-empty PM selection. The selection range is captured
   * so the eventual Apply / Remove uses the correct positions even after
   * focus moves to the URL input.
   */
  @action
  enterLinkMode() {
    const view = this.#view;
    if (!view) {
      return;
    }
    const { from, to } = view.state.selection;
    if (from === to) {
      return;
    }
    this.#savedLinkRange = { from, to };
    this.linkEditUrl =
      existingLinkHref(view.state, view.state.schema.marks.link) ?? "";
    this.linkEditMode = true;
  }

  /**
   * Applies (or replaces) the link mark using the URL currently in
   * `linkEditUrl`. An empty URL falls through to a mark removal so an
   * author can clear a link by emptying the field and pressing Enter.
   */
  @action
  applyLink() {
    const view = this.#view;
    const range = this.#savedLinkRange;
    if (!view || !range) {
      this.#exitLinkMode();
      return;
    }
    const markType = view.state.schema.marks.link;
    const tr = view.state.tr;
    tr.removeMark(range.from, range.to, markType);
    const trimmed = this.linkEditUrl.trim();
    if (trimmed) {
      tr.addMark(range.from, range.to, markType.create({ href: trimmed }));
    }
    tr.setSelection(
      this.#pm.TextSelection.create(tr.doc, range.from, range.to)
    );
    view.dispatch(tr);
    view.focus();
    this.#exitLinkMode();
  }

  @action
  removeLink() {
    const view = this.#view;
    const range = this.#savedLinkRange;
    if (!view || !range) {
      this.#exitLinkMode();
      return;
    }
    const markType = view.state.schema.marks.link;
    const tr = view.state.tr.removeMark(range.from, range.to, markType);
    tr.setSelection(
      this.#pm.TextSelection.create(tr.doc, range.from, range.to)
    );
    view.dispatch(tr);
    view.focus();
    this.#exitLinkMode();
  }

  @action
  cancelLink() {
    this.#view?.focus();
    this.#exitLinkMode();
  }

  #exitLinkMode() {
    this.linkEditMode = false;
    this.linkEditUrl = "";
    this.#savedLinkRange = null;
  }

  /**
   * Builds a PM keymap command that moves the inline edit session to the
   * next (`direction = 1`) or previous (`direction = -1`) rich-inline
   * arg span inside the same block, in DOM order. Returns a synchronous
   * boolean — `true` when the command consumed the keystroke, `false`
   * when there's no neighbour and the browser's default Tab handling
   * should run.
   */
  #tabToSiblingArg(direction) {
    return () => {
      const view = this.#view;
      if (!view) {
        return false;
      }
      const blockEl = view.dom.closest("[data-ve-block-key]");
      if (!blockEl) {
        return false;
      }
      const argEls = Array.from(
        blockEl.querySelectorAll("[data-ve-inline-edit-arg]")
      );
      const currentArg = this.visualEditor.editingArgName;
      const i = argEls.findIndex(
        (el) => el.dataset.veInlineEditArg === currentArg
      );
      if (i === -1) {
        return false;
      }
      const next = argEls[i + direction];
      if (!next) {
        return false;
      }
      this.visualEditor.startEditingArg(
        blockEl.dataset.veBlockKey,
        next.dataset.veInlineEditArg
      );
      return true;
    };
  }

  <template>
    {{! insertBefore=null keeps the renderer's existing __content span
        intact instead of wiping it. The default in-element behavior
        replaces the destination's children — fine for a fresh mount,
        but it leaves the renderer span permanently empty once the
        portal unmounts, since Glimmer doesn't restore what it cleared.
        We need the rendered text to be there both during the edit
        (hidden by the --editing class) AND after the editor goes away. }}
    {{#if this.activeRendererEl}}
      {{#in-element this.activeRendererEl insertBefore=null}}
        <span
          class="ve-inline-editor-mount"
          {{didInsert this.mountEditor}}
          {{willDestroy this.unmountEditor}}
        ></span>
      {{/in-element}}
    {{/if}}
  </template>
}

/**
 * Returns `true` when the current selection has the given mark applied
 * (or, for empty selections, when `storedMarks` carries it).
 *
 * @param {import("prosemirror-state").EditorState} state
 * @param {import("prosemirror-model").MarkType | undefined} markType
 * @returns {boolean}
 */
function hasMark(state, markType) {
  if (!markType) {
    return false;
  }
  const { from, $from, to, empty } = state.selection;
  if (empty) {
    return !!markType.isInSet(state.storedMarks || $from.marks());
  }
  return state.doc.rangeHasMark(from, to, markType);
}

/**
 * Walks the current selection and returns the first link mark's `href`,
 * or `null` when no link mark touches the range. Used to prefill the
 * URL input when entering link-edit mode over an already-linked range.
 */
function existingLinkHref(state, markType) {
  if (!markType) {
    return null;
  }
  const { from, to } = state.selection;
  let href = null;
  state.doc.nodesBetween(from, to, (node) => {
    const mark = node.marks.find((m) => m.type === markType);
    if (mark && href === null) {
      href = mark.attrs?.href ?? null;
    }
  });
  return href;
}

/**
 * PM keymap command that inserts a `hard_break` node at the cursor — used
 * by paragraph-schema Enter handling in Phase 1. Phase 3 replaces this
 * with the split-into-new-block behavior.
 */
function insertHardBreak(schema) {
  return (state, dispatch) => {
    if (!schema.nodes.hard_break) {
      return false;
    }
    const br = schema.nodes.hard_break.create();
    if (dispatch) {
      dispatch(state.tr.replaceSelectionWith(br).scrollIntoView());
    }
    return true;
  };
}

/**
 * Block keys contain colons (`ve:heading:abc`) and other CSS-meaningful
 * characters that would break a raw attribute selector. `CSS.escape` is
 * available in every supported browser; the fallback is a defensive
 * regex for older environments.
 */
function cssEscape(value) {
  if (typeof CSS !== "undefined" && typeof CSS.escape === "function") {
    return CSS.escape(value);
  }
  return String(value).replace(/[^a-zA-Z0-9_-]/g, "\\$&");
}
