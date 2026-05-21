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
import InlineEditToolbar from "./inline-edit-toolbar";

/**
 * Mounts a ProseMirror editor over the currently-edited inline text region.
 *
 * Watches `visualEditor.editingBlockKey` + `editingArgName`. When set, it
 * locates the matching renderer span via a DOM query against the canvas
 * (`[data-ve-block-key="..."] [data-ve-inline-edit-arg="..."]`), reads the
 * schema variant off `data-ve-inline-edit-schema`, and mounts an editor
 * into the span via `{{in-element}}`. Per-keystroke changes stream through
 * `visualEditor.applyInlineEditChange` (no undo push); Escape and outside
 * clicks call `visualEditor.stopEditing()`, which records exactly one
 * `{ kind: "args" }` undo entry on commit.
 *
 * The block components and the renderer never see this code — they emit
 * data-attrs and render normally. All editing UX lives here.
 *
 * ProseMirror modules are lazy-loaded the first time the user enters an
 * edit session (matching the composer's `loadRichEditor` pattern), so the
 * PM bundle doesn't ship with the admin page unless the author actually
 * starts editing inline text.
 */
export default class InlineEditController extends Component {
  @service visualEditor;

  /**
   * Floating-toolbar state. `null` when the toolbar should be hidden
   * (no selection, empty selection, or `plain` schema with no marks).
   * The toolbar component reads `{view, left, top, isStrongActive, ...}`
   * straight out. Updated in `dispatchTransaction` after every PM
   * state change, plus on initial mount.
   *
   * `@tracked` so the template re-renders when the user selects text
   * or toggles a mark. Template-facing (read directly via `this.toolbarState`),
   * so unprefixed per the public-template convention in CLAUDE.local.md.
   *
   * @type {import("./inline-edit-toolbar").InlineEditToolbarState | null}
   */
  @tracked toolbarState = null;

  #view = null;
  #handleOutsideClick = null;
  #editingRendererEl = null;

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

  @action
  async mountEditor(container) {
    const rendererEl = this.activeRendererEl;
    if (!rendererEl) {
      return;
    }
    this.#editingRendererEl = rendererEl;

    const pm = await loadInlineRichEditor();

    // The session could have already ended (Escape / outside click) between
    // the click and the PM bundle resolving. If so, bail without mounting.
    if (this.activeRendererEl !== rendererEl) {
      return;
    }

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
      }),
    ];

    this.#view = new pm.EditorView(container, {
      state: pm.EditorState.create({ schema, doc, plugins }),
      attributes: { class: "ve-inline-editor" },
      dispatchTransaction: (tr) => {
        // ProseMirror is the visible source of truth for the duration of
        // the session — we DO NOT write back to `args` per keystroke.
        // The commit callback registered below pulls the final doc once,
        // on session end. Per-keystroke writes exposed the system to
        // spurious "PM emptied its doc during teardown" transactions
        // that clobbered `args.text` with `""`.
        const view = this.#view;
        if (!view) {
          return;
        }
        view.updateState(view.state.apply(tr));
        this.#refreshToolbarState();
      },
    });

    // Hand the service a way to pull the final doc when it decides to
    // end the session (Escape, outside-click, selectBlock onto another
    // block, etc.). The service invokes this BEFORE clearing
    // `editingLocated`, so `applyInlineEditChange` still resolves the
    // right entry.
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
    this.#refreshToolbarState();

    this.#handleOutsideClick = (event) => {
      if (!this.#view || this.#view.dom.contains(event.target)) {
        return;
      }
      // The bubble toolbar is portaled at canvas level (outside view.dom),
      // so a click on its buttons would otherwise look like an outside
      // click and exit the session. Treat any click inside the toolbar
      // as inside the editor.
      if (event.target.closest?.(".ve-inline-edit-toolbar")) {
        return;
      }
      // Defer one frame so a click on a sibling `[data-ve-inline-edit-arg]`
      // (which dispatches its own `startEditingArg` via the canvas's
      // delegated click handler) wins the race against this stopEditing.
      // After the frame, if the editing target is still this renderer,
      // the user really did click outside — commit and exit.
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
    // Drop the commit hook first so any in-flight stopEditing call doesn't
    // re-enter into a stale view.
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
    this.toolbarState = null;
  }

  /**
   * Recomputes the toolbar's position and active-mark flags from the
   * current PM selection. Called after every dispatched transaction and
   * once after the initial mount. Hides the toolbar (sets state to
   * `null`) when:
   *   - PM isn't mounted
   *   - the selection is empty (nothing to format)
   *   - the schema doesn't allow marks (the `plain` variant)
   */
  #refreshToolbarState() {
    const view = this.#view;
    if (!view) {
      this.toolbarState = null;
      return;
    }
    const variant = SCHEMAS[this.schemaName];
    if (!variant?.allowsMarks) {
      this.toolbarState = null;
      return;
    }
    const { from, to, empty } = view.state.selection;
    if (empty) {
      this.toolbarState = null;
      return;
    }
    const { schema } = view.state;
    const fromCoords = view.coordsAtPos(from);
    const toCoords = view.coordsAtPos(to);
    this.toolbarState = {
      view,
      left: (fromCoords.left + toCoords.left) / 2,
      top: fromCoords.top,
      isStrongActive: hasMark(view.state, schema.marks.strong),
      isEmActive: hasMark(view.state, schema.marks.em),
      isLinkActive: hasMark(view.state, schema.marks.link),
    };
  }

  <template>
    {{! insertBefore=null keeps the renderer's existing __content span
        intact instead of wiping it. The default in-element behavior
        replaces the destination's children — fine for a fresh mount, but
        it leaves the renderer span permanently empty once the portal
        unmounts, since Glimmer doesn't restore what it cleared. We need
        the rendered text to be there both during the edit (hidden by the
        --editing class) AND after the editor goes away. }}
    {{#if this.activeRendererEl}}
      {{#in-element this.activeRendererEl insertBefore=null}}
        <span
          class="ve-inline-editor-mount"
          {{didInsert this.mountEditor}}
          {{willDestroy this.unmountEditor}}
        ></span>
      {{/in-element}}
    {{/if}}
    {{#if this.toolbarState}}
      <InlineEditToolbar @state={{this.toolbarState}} />
    {{/if}}
  </template>
}

/**
 * Returns `true` when the current selection has the given mark applied
 * (or, for empty selections, when `storedMarks` carries it). Inlined here
 * rather than imported from `discourse/static/prosemirror/lib/plugin-utils`
 * because that path lives in a lazy chunk plugin code can't statically
 * import.
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
