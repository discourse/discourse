// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import {
  existingLinkHref,
  hasMark,
  insertHardBreak,
  SCHEMAS,
  toDoc,
  toStorage,
} from "discourse/plugins/discourse-wireframe/discourse/lib/rich-text";

/**
 * Mounts a ProseMirror editor over the currently-edited inline text region
 * and exposes its commands to the block-toolbar.
 *
 * Watches `wireframeInplaceText.blockKey` + `argName`. When set, it
 * locates the matching renderer span via a DOM query against the canvas
 * (`[data-wf-block-key="..."] [data-block-arg="..."]`), reads the
 * schema variant off `data-block-arg-schema`, and mounts a constrained
 * PM editor into the span via `{{in-element insertBefore=null}}`. PM is the
 * source of truth during the session — `args.text` is written once at
 * commit time, not per keystroke.
 *
 * The bold / italic / link UI lives in `block-toolbar.gjs` (shared with the
 * block move/duplicate/delete buttons). The block-toolbar reaches this
 * controller via `wireframeInplaceText.controller` and calls its methods
 * (`toggleMark`, `enterLinkMode`, etc.); a tracked `_pmStateVersion`
 * counter bumps on every PM transaction so the toolbar's `markState`
 * getter (which depends on PM state) re-evaluates reactively.
 *
 * ProseMirror modules are lazy-loaded the first time the user enters an
 * edit session — see `discourse/lib/load-inline-rich-editor`.
 */
export default class InplaceTextController extends Component {
  @service wireframeInplaceText;

  #view = null;
  #pm = null;
  #handleOutsideClick = null;
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
    this.wireframeInplaceText.registerController(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.wireframeInplaceText.unregisterController(this);
  }

  /**
   * The renderer span the editor should mount into, looked up off the
   * service's `wireframeInplaceText.(blockKey, argName)`. Returns `null` when no
   * session is active or when the renderer hasn't rendered yet (the
   * canvas may be in the middle of swapping blocks).
   *
   * Matched on `data-wf-rich-text-arg` — the dedicated marker only the
   * rich-text renderer emits — NOT the generic `data-block-arg` (which
   * also tags image / URL / icon args). This is a structural guard: the
   * editor can only ever mount into a real rich-text field, so a stray
   * `wireframeInplaceText.start` on a non-text arg resolves to `null` and mounts
   * nothing.
   *
   * @returns {HTMLElement | null}
   */
  @cached
  get activeRendererEl() {
    // Read the tracked session identity FIRST so this `@cached` getter always
    // depends on it and recomputes on every session transition. The
    // container-arg branch below returns early; without these reads up here it
    // would capture no tracked dependency for a container-arg session and the
    // cache would stick on the first target's element — leaving ProseMirror
    // mounted there while later commits write to the new session target (the
    // tab-label value bled into other tabs / paragraphs). `blockKey` is set to
    // the child key on each container-arg session, so it changes per target.
    const { blockKey, argName } = this.wireframeInplaceText;

    // ContainerArg session (e.g. a tab-strip label): the editable span lives in
    // the PARENT's render, not the child's chrome, so it's resolved by a
    // dedicated `[data-wf-container-arg-key]` marker rather than the child's
    // `data-wf-block-key` (which also tags the child's panel chrome — reusing it
    // would be ambiguous).
    const containerArg = this.wireframeInplaceText.containerArgContext;
    if (containerArg) {
      const { childKey, namespace, field } = containerArg;
      const host =
        `[data-wf-container-arg-key="${CSS.escape(childKey)}"]` +
        `[data-wf-container-arg-namespace="${CSS.escape(namespace)}"]` +
        `[data-wf-container-arg-field="${CSS.escape(field)}"]`;
      return document.querySelector(`${host} [data-wf-rich-text-arg]`);
    }

    if (!blockKey || !argName) {
      return null;
    }
    const blockSelector = `[data-wf-block-key="${CSS.escape(blockKey)}"]`;
    const argSelector = `[data-wf-rich-text-arg="${CSS.escape(argName)}"]`;
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
    const raw = el?.dataset?.blockArgSchema;
    return raw && raw in SCHEMAS ? raw : "plain";
  }

  /**
   * Public API consumed by `block-toolbar.gjs`. Returns the
   * active-mark flags for the current PM selection, or `null` when the
   * inline-format buttons should be hidden (no view, empty selection,
   * or schema that doesn't allow marks). Reached via
   * `wireframeInplaceText.controller.markState`.
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

    const pm = await loadInlineRichEditor();

    if (this.activeRendererEl !== rendererEl) {
      return;
    }

    this.#pm = pm;

    const variant = SCHEMAS[this.schemaName];
    const schema = pm.createSchema(variant.extensions, false);
    const doc = pm.Node.fromJSON(
      schema,
      toDoc(this.wireframeInplaceText.argValue)
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
          this.wireframeInplaceText.stop({ commit: true });
          return true;
        },
        Enter: this.#enterCommand(schema),
        "Shift-Enter":
          this.schemaName === "paragraph" && variant.allowsHardBreak
            ? insertHardBreak(schema)
            : undefined,
        // Backspace at position 0 of a `wf:paragraph` block merges
        // this paragraph into the previous sibling — but only when
        // the prev is also a `wf:paragraph` (the helper checks this
        // and returns false otherwise, so PM falls through to its
        // default delete-a-char behavior). Other schemas / blocks
        // get no special handling; Backspace stays a plain delete.
        Backspace:
          this.wireframeInplaceText.blockName === "paragraph"
            ? this.#mergeWithPrevAtStart()
            : undefined,
        // Cross-block arrow nav between sibling `wf:paragraph` blocks.
        // Left at pos 0 / Up on the first visual line → end of prev.
        // Right at end / Down on the last visual line → start of next.
        // All four return false (and PM's default arrow handling
        // takes over) when the cursor isn't at the edge or the
        // adjacent sibling isn't a `wf:paragraph`.
        ...(this.wireframeInplaceText.blockName === "paragraph" && {
          ArrowLeft: this.#walkToSibling("prev", "horizontal"),
          ArrowRight: this.#walkToSibling("next", "horizontal"),
          ArrowUp: this.#walkToSibling("prev", "vertical"),
          ArrowDown: this.#walkToSibling("next", "vertical"),
        }),
        // Tab walks between rich-inline fields on the same block in DOM
        // order. The service's `wireframeInplaceText.start` implicitly commits the
        // current session, so chaining Tabs across fields produces one
        // undo entry per visited field. At the first / last field the
        // command commits the current field, ends the session, and returns
        // false so the browser's default Tab handling moves focus on to the
        // next element — the editor exits instead of trapping focus.
        Tab: this.#tabToSiblingArg(1),
        "Shift-Tab": this.#tabToSiblingArg(-1),
      }),
    ];

    this.#view = new pm.EditorView(container, {
      state: pm.EditorState.create({ schema, doc, plugins }),
      attributes: { class: "wf-rich-text-editor" },
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

    this.wireframeInplaceText.registerCommit(() => {
      const finalView = this.#view;
      if (!finalView) {
        return;
      }
      const docJson = finalView.state.doc.toJSON();
      this.wireframeInplaceText.applyChange(toStorage(docJson));
    });

    // Initial selection. `"selectAll"` (the default) is the "start
    // typing to replace" affordance for fresh edit sessions. `"start"`
    // and `"end"` are used by structural transitions (Enter-split
    // sets `"start"`). A `{ pos }` hint is used by Backspace-merge to
    // place the cursor at the absolute join position. A `{ coords }`
    // hint comes from the click-to-edit gesture and places the cursor
    // at the click point via PM's `posAtCoords` — when that returns
    // null (click landed outside any text node, e.g. past end-of-line
    // whitespace), we fall back to end-of-doc which is more natural
    // than selecting all when the user's intent was to position the
    // cursor. The service drives the hint and resets it to `"selectAll"`
    // on consumption.
    const initialDoc = this.#view.state.doc;
    const end = initialDoc.content.size;
    const hint = this.wireframeInplaceText.consumeInitialSelectionHint();
    let range;
    if (hint && typeof hint === "object" && hint.coords) {
      const coordResult = this.#view.posAtCoords({
        left: hint.coords.x,
        top: hint.coords.y,
      });
      const pos = coordResult ? coordResult.pos : end;
      range = pm.TextSelection.create(initialDoc, pos, pos);
    } else if (
      hint &&
      typeof hint === "object" &&
      typeof hint.pos === "number"
    ) {
      const pos = Math.max(0, Math.min(end, hint.pos));
      range = pm.TextSelection.create(initialDoc, pos, pos);
    } else if (hint === "start") {
      range = pm.TextSelection.create(initialDoc, 0, 0);
    } else if (hint === "end") {
      range = pm.TextSelection.create(initialDoc, end, end);
    } else {
      range = pm.TextSelection.create(initialDoc, 0, end);
    }
    this.#view.dispatch(this.#view.state.tr.setSelection(range));
    this.#view.focus();

    this.#handleOutsideClick = (event) => {
      if (!this.#view || this.#view.dom.contains(event.target)) {
        return;
      }
      // The block-toolbar (which now hosts the inline-format buttons) sits
      // outside view.dom but is functionally part of the editor. Treat
      // clicks inside any block-toolbar as inside the editor so the
      // session doesn't exit when applying a mark.
      if (event.target.closest?.(".wireframe-block-toolbar")) {
        return;
      }
      // A click on a rich-inline field region of THIS block stays in edit:
      // it's either the current field's own padding (cursor placement) or
      // another field, which the chrome's onClick transitions to via
      // `start()`'s implicit commit. The rAF guard below would otherwise
      // race and stop that just-opened session. Any other same-block click
      // (the icon area, the block chrome gutter, padding off the text) falls
      // through and commits + exits.
      const editingBlock = this.activeRendererEl?.closest?.(
        "[data-wf-block-key]"
      );
      if (
        editingBlock?.contains(event.target) &&
        event.target.closest?.("[data-wf-rich-text-arg]")
      ) {
        return;
      }
      // Bail out if the edit session has already ended (e.g. a sibling
      // click handler called `wireframeInplaceText.stop` first). `activeRendererEl`
      // returns `null` when there's no active session.
      requestAnimationFrame(() => {
        if (this.activeRendererEl) {
          this.wireframeInplaceText.stop({ commit: true });
        }
      });
    };
    document.addEventListener("mousedown", this.#handleOutsideClick, true);
  }

  @action
  unmountEditor() {
    this.wireframeInplaceText.registerCommit(null);

    const view = this.#view;
    this.#view = null;
    if (view) {
      view.destroy();
    }
    if (this.#handleOutsideClick) {
      document.removeEventListener("mousedown", this.#handleOutsideClick, true);
      this.#handleOutsideClick = null;
    }
    this.#savedLinkRange = null;
    // Clear the toolbar slot if this controller owned a URL session
    // (e.g. user closed PM mid-link-edit).
    if (this.wireframeInplaceText.fieldEditor?.kind === "url") {
      this.wireframeInplaceText.setFieldEditor(null);
    }
    // Force a re-evaluation of `markState` so the toolbar hides cleanly.
    this._pmStateVersion++;
  }

  /**
   * Toggles `strong` or `em` over the current PM selection. Called by
   * the block-toolbar's inline-format buttons (via
   * `wireframeInplaceText.controller.toggleMark`).
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
   * Transitions the block toolbar into URL-edit mode for the current
   * non-empty PM selection by populating `wireframeInplaceText.fieldEditor` with
   * a URL slot that wires apply / cancel / remove back to the PM
   * mark mutations below. The selection range is captured so those
   * mutations land on the correct positions even after focus moves
   * to the URL input.
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
    const existing =
      existingLinkHref(view.state, view.state.schema.marks.link) ?? "";
    this.wireframeInplaceText.setFieldEditor({
      kind: "url",
      value: existing,
      apply: (newValue) => this.#applyLink(newValue),
      cancel: () => this.#cancelLink(),
      remove: () => this.#removeLink(),
    });
  }

  /**
   * Applies (or replaces) the link mark using the URL passed in from
   * the toolbar. An empty URL falls through to a mark removal so an
   * author can clear a link by emptying the field and pressing Enter.
   */
  #applyLink(newValue) {
    const view = this.#view;
    const range = this.#savedLinkRange;
    if (!view || !range) {
      this.#exitLinkMode();
      return;
    }
    const markType = view.state.schema.marks.link;
    const tr = view.state.tr;
    tr.removeMark(range.from, range.to, markType);
    const trimmed = (newValue ?? "").trim();
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

  #removeLink() {
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

  #cancelLink() {
    this.#view?.focus();
    this.#exitLinkMode();
  }

  #exitLinkMode() {
    this.#savedLinkRange = null;
    if (this.wireframeInplaceText.fieldEditor?.kind === "url") {
      this.wireframeInplaceText.setFieldEditor(null);
    }
  }

  /**
   * Builds a PM keymap command that moves the inline edit session to the
   * next (`direction = 1`) or previous (`direction = -1`) rich-inline
   * arg span inside the same block, in DOM order. Returns a synchronous
   * boolean — `true` when the command consumed the keystroke, `false`
   * when there's no neighbour and the browser's default Tab handling
   * should run.
   *
   * Walks `[data-wf-rich-text-arg]` elements only — the dedicated
   * rich-text marker — so Tab never lands on image / URL / icon args
   * (which carry the generic `data-block-arg` but not this marker).
   */
  #tabToSiblingArg(direction) {
    return () => {
      const view = this.#view;
      if (!view) {
        return false;
      }
      const blockEl = view.dom.closest("[data-wf-block-key]");
      if (!blockEl) {
        return false;
      }
      const argEls = Array.from(
        blockEl.querySelectorAll("[data-wf-rich-text-arg]")
      );
      const currentArg = this.wireframeInplaceText.argName;
      const i = argEls.findIndex(
        (el) => el.dataset.wfRichTextArg === currentArg
      );
      if (i === -1) {
        return false;
      }
      const next = argEls[i + direction];
      if (!next) {
        // No sibling field this direction: commit the current field and end
        // the session. Returning false lets the browser's default Tab move
        // focus on to the next element, so the editor exits cleanly instead
        // of trapping focus.
        this.wireframeInplaceText.stop({ commit: true });
        return false;
      }
      this.wireframeInplaceText.start(
        blockEl.dataset.wfBlockKey,
        next.dataset.wfRichTextArg
      );
      return true;
    };
  }

  /**
   * Picks the Enter handler for the active session based on schema +
   * block type:
   *   - paragraph schema + `wf:paragraph` block → split the block at
   *     the cursor. The current entry keeps the "before" doc; a new
   *     sibling holds the "after" doc.
   *   - paragraph schema + other block (callout body, banner content,
   *     media-card title, …) → insert a `hard_break`. Splitting a
   *     callout / banner / card into two of itself has no semantic
   *     meaning, so the per-block soft-wrap stays.
   *   - heading / plain → commit and exit.
   *
   * Shift+Enter keeps the existing `hard_break` path in any paragraph-
   * schema editor (handled separately at the keymap site), so authors
   * can still soft-wrap inside a paragraph block.
   *
   * @param {import("prosemirror-model").Schema} schema
   */
  #enterCommand(schema) {
    if (this.schemaName !== "paragraph") {
      return () => {
        this.wireframeInplaceText.stop({ commit: true });
        return true;
      };
    }
    if (this.wireframeInplaceText.blockName === "paragraph") {
      return this.#splitParagraphAtCursor();
    }
    return insertHardBreak(schema);
  }

  /**
   * Builds a PM keymap command for paragraph-block Enter: slices the
   * current PM doc at the cursor into a `before` doc-JSON and an
   * `after` doc-JSON, then hands them to the service's `wireframeInplaceText.splitAt`
   * action. PM's `Node.cut(from, to)` returns a doc-shaped node
   * containing the slice — calling `toJSON()` on each gives the
   * storage-ready doc-JSON the service writes back via `toStorage`.
   * Returns `true` when the split fires (consumes the keystroke);
   * `false` when the session state is wrong so PM falls through to the
   * next command in the keymap.
   */
  #splitParagraphAtCursor() {
    return () => {
      const view = this.#view;
      if (!view) {
        return false;
      }
      const { doc, selection } = view.state;
      const cursor = selection.from;
      const beforeDoc = doc.cut(0, cursor).toJSON();
      const afterDoc = doc.cut(cursor, doc.content.size).toJSON();
      return this.wireframeInplaceText.splitAt({ beforeDoc, afterDoc });
    };
  }

  /**
   * Builds a PM keymap command for paragraph-block Backspace at the
   * start of the doc: merges the current paragraph into the previous
   * sibling when both are `wf:paragraph` entries. Reconstructs the
   * prev's PM doc from its stored value via the same schema, concats
   * the current doc onto it, and hands the merged doc-JSON to the
   * service along with `joinPos` — the doc position where the merge
   * boundary sits (= prev's content size before the concat). The
   * service swaps the active session over to the prev entry with
   * a `{ pos: joinPos }` initial-selection hint so the cursor lands
   * at the join.
   *
   * Returns `false` (PM falls through to its default Backspace, which
   * deletes a char) when any of the merge preconditions are missing:
   * selection isn't a collapsed cursor at position 0, no prev sibling
   * in the same outlet, or the prev sibling isn't a `wf:paragraph`.
   */
  #mergeWithPrevAtStart() {
    return () => {
      const view = this.#view;
      if (!view) {
        return false;
      }
      const { doc, selection, schema } = view.state;
      if (!selection.empty || selection.from !== 0) {
        return false;
      }
      const prev = this.wireframeInplaceText.prevSiblingInfo();
      if (!prev || prev.block !== "paragraph") {
        return false;
      }
      const prevDoc = schema.nodeFromJSON(toDoc(prev.value));
      const joinPos = prevDoc.content.size;
      const mergedDoc = prevDoc.replace(joinPos, joinPos, doc.slice(0));
      return this.wireframeInplaceText.mergeWithPrev({
        mergedDoc: mergedDoc.toJSON(),
        joinPos,
      });
    };
  }

  /**
   * Builds a PM keymap command that walks the inline edit session to a
   * sibling `wf:paragraph` block. `direction` picks prev / next;
   * `axis` controls the at-edge check:
   *
   *   - `"horizontal"` — fires when the cursor is at the absolute
   *     start (prev) / end (next) of the doc. Wired to ArrowLeft /
   *     ArrowRight.
   *   - `"vertical"`   — fires when the cursor sits on the first
   *     (prev) / last (next) visual line, detected via PM's
   *     `view.endOfTextblock("up"|"down")`. Wired to ArrowUp /
   *     ArrowDown.
   *
   * Returns `false` (PM's default arrow handling takes over) when the
   * selection isn't a collapsed cursor at the relevant edge, no
   * sibling exists, or the sibling isn't a `wf:paragraph`. On a
   * successful walk, `wireframeInplaceText.start` commits the current session
   * (one undo entry), opens a session on the sibling with an `"end"`
   * (prev) / `"start"` (next) initial-selection hint, and the cursor
   * lands at the matching edge of the sibling's doc.
   */
  #walkToSibling(direction, axis) {
    return () => {
      const view = this.#view;
      if (!view) {
        return false;
      }
      const { doc, selection } = view.state;
      if (!selection.empty) {
        return false;
      }
      const atEdge =
        axis === "horizontal"
          ? direction === "prev"
            ? selection.from === 0
            : selection.from === doc.content.size
          : view.endOfTextblock(direction === "prev" ? "up" : "down");
      if (!atEdge) {
        return false;
      }
      const sibling =
        direction === "prev"
          ? this.wireframeInplaceText.prevSiblingInfo()
          : this.wireframeInplaceText.nextSiblingInfo();
      if (!sibling || sibling.block !== "paragraph") {
        return false;
      }
      this.wireframeInplaceText.start(sibling.key, "text", {
        initialSelection: direction === "prev" ? "end" : "start",
      });
      return true;
    };
  }

  <template>
    {{! insertBefore=null keeps the renderer's existing __content span
        intact instead of wiping it. The default in-element behavior
        replaces the destination's children — Glimmer keeps its tracking
        references on those children but they're detached from the
        document, so subsequent patches (after value or runs change on
        commit) land on orphan nodes and never re-appear.
        insertBefore=null switches the portal to append-as-sibling mode
        so __content stays in the document, Glimmer's tracking stays in
        sync with reality, and the rendered text comes back on commit.
        We verified this empirically. }}
    {{#if this.activeRendererEl}}
      {{#in-element this.activeRendererEl insertBefore=null}}
        <span
          class="wf-rich-text-editor-mount"
          {{didInsert this.mountEditor}}
          {{willDestroy this.unmountEditor}}
        ></span>
      {{/in-element}}
    {{/if}}
  </template>
}
