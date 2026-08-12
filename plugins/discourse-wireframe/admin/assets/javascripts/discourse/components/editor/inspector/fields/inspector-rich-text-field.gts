import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import loadInlineRichEditor from "discourse/lib/load-inline-rich-editor";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import {
  existingLinkHref,
  hasMark,
  insertHardBreak,
  type RichTextDoc,
  SCHEMAS,
  toDoc,
  toStorage,
} from "discourse/plugins/discourse-wireframe/discourse/lib/rich-text";
import type WireframeInplaceTextService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-inplace-text";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

type StoredRichTextValue = string | RichTextDoc;
type InlineRichEditor = Awaited<ReturnType<typeof loadInlineRichEditor>>;
type InlineRichEditorView = InstanceType<InlineRichEditor["EditorView"]>;
type InlineRichEditorTransaction = Parameters<
  InlineRichEditorView["dispatch"]
>[0];
type RichTextSchemaName = keyof typeof SCHEMAS;

type RichTextFieldData = {
  /** FormKit field name. */
  name: string;
  /** Current FormKit field value. */
  value: unknown;
  /** Writes a replacement FormKit field value. */
  set: (value: StoredRichTextValue) => void | Promise<void>;
};

// TODO(devxp-typescript-pending): replace `RichTextFieldData` once FormKit
// exports the type of the field data yielded by a custom control.

type MarkState = {
  /** Whether the strong mark is active. */
  strong: boolean;
  /** Whether the emphasis mark is active. */
  em: boolean;
  /** Whether the link mark is active. */
  link: boolean;
};

type SavedLinkRange = {
  /** Inclusive link range start. */
  from: number;
  /** Exclusive link range end. */
  to: number;
};

interface InspectorRichTextFieldSignature {
  /** Rich-text value and schema variant. */
  Args: {
    /** FormKit field data read and updated by the editor. */
    custom: RichTextFieldData;
    /** Rich-text schema variant requested by the argument metadata. */
    schema: string;
  };
}

/**
 * Compares two stored rich-inline values (each a plain string or a doc-JSON
 * object). Used as the commit dirty-check so an edit session that didn't
 * change anything doesn't write back through the form.
 *
 * @param a - First stored value.
 * @param b - Second stored value.
 * @returns Whether the values have equivalent storage representations.
 */
function valuesEqual(
  a: StoredRichTextValue | undefined,
  b: StoredRichTextValue | undefined
): boolean {
  if (a === b) {
    return true;
  }
  if (typeof a === "string" || typeof b === "string") {
    return false;
  }
  return JSON.stringify(a) === JSON.stringify(b);
}

/**
 * Editable inspector control for a `richInline` arg. Mounts a constrained
 * ProseMirror editor (the same lib the canvas inline editor uses —
 * `loadInlineRichEditor` + the `SCHEMAS` extension lists) directly in the
 * inspector, with a small bold / italic / link toolbar, so authors can edit
 * formatted text without the canvas (headless / no-canvas editing).
 *
 * The control is draft-independent: it seeds from the field value once, holds
 * the document in ProseMirror during the session, and commits the result
 * (`toStorage` — a plain string when there are no marks, doc-JSON otherwise)
 * back through the FormKit field on blur and on teardown. Committing on blur
 * (not per keystroke) keeps it to one write per edit session, which matters
 * for the container-arg path (tab labels) where each write is an immediate
 * structural mutation.
 *
 * Args:
 *   `@custom`  the FormKit FieldData (reads `.value`, writes `.set`, `.name`).
 *   `@schema`  the variant name (`plain` / `heading` / `paragraph`) — picks the
 *            allowed marks / line breaks. Supplied from the arg's `ui.schema`.
 */
export default class InspectorRichTextField extends Component<InspectorRichTextFieldSignature> {
  /** Coordinates the canvas in-place text editor. */
  @service declare wireframeInplaceText: WireframeInplaceTextService;

  /** Invalidates live value reads after layout changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Provides the selected block and its live arguments. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Whether the inline link input is open. */
  @tracked linkMode: boolean = false;

  /** Draft URL shown in the inline link input. */
  @tracked linkValue: string = "";

  /** Mounted ProseMirror view. */
  #view: InlineRichEditorView | null = null;

  /** Lazily loaded ProseMirror surface. */
  #pm: InlineRichEditor | null = null;

  /** Root element containing the editor and toolbar. */
  #rootEl: HTMLElement | null = null;

  /** Most recently committed stored value. */
  #committedValue: StoredRichTextValue | undefined;

  /** Selection range preserved while the URL input owns focus. */
  #savedLinkRange: SavedLinkRange | null = null;

  /**
   * Bumped on every ProseMirror transaction so `markState` (which reads PM
   * state, untracked by Glimmer) re-evaluates and the toolbar's active-mark
   * buttons re-render. Not read from the template directly.
   */
  @tracked _pmStateVersion: number = 0;

  /** Active rich-text schema variant. */
  get #schemaName(): RichTextSchemaName {
    const raw = this.args.schema;
    return isRichTextSchemaName(raw) ? raw : "plain";
  }

  /** Whether the active schema allows formatting marks. */
  get showToolbar(): boolean {
    return SCHEMAS[this.#schemaName].allowsMarks;
  }

  /**
   * `true` when the canvas is in-place editing this exact block + arg. The editor
   * stays mounted but goes inert (non-editable, dimmed, toolbar disabled) so
   * there's never a second live editor competing for the same value — and no
   * component swap, so the rendered formatting and layout stay put.
   *
   * @returns Whether the canvas editor currently owns this value.
   */
  get readOnly(): boolean {
    const inlineEdit = this.wireframeInplaceText;
    return !!(
      inlineEdit.isActive &&
      inlineEdit.argName === this.args.custom.name &&
      inlineEdit.blockKey === this.wireframeSelection.selectedBlockKey
    );
  }

  /**
   * The value to seed (and re-seed) the editor from. Prefers the LIVE block-arg
   * value off the entry's tracked args, so an external edit — the canvas inline
   * editor committing the same arg, a paste, an undo — flows back into this
   * editor; reading the property opens a tracked dep, and `wireframeLayoutSignal.version`
   * covers the entry being replaced under the selection. Falls back to the
   * FormKit draft for non-block-arg fields (container args like tab labels,
   * whose value lives outside `args`), which keep their selection-time value.
   *
   * @returns Current stored rich-text value.
   */
  get liveValue(): StoredRichTextValue {
    void this.wireframeLayoutSignal.version;
    const data = this.wireframeSelection.selectedBlockData;
    const name = this.args.custom.name;
    if (name && data?.metadata?.args && name in data.metadata.args) {
      // TODO(devxp-typescript-pending): the stored arg value is `unknown`; the
      // raw read forwards it (or "") directly rather than coercing at this
      // boundary.
      return (data.args?.[name] ?? "") as StoredRichTextValue;
    }
    // TODO(devxp-typescript-pending): the form draft value is `unknown`; the
    // raw read forwards it (or "") directly rather than coercing at this
    // boundary.
    return (this.args.custom?.value ?? "") as StoredRichTextValue;
  }

  /**
   * Active-mark flags for the current selection, or `null` when the toolbar
   * buttons should read inactive (no view, empty selection, or a schema with
   * no marks). Reading `_pmStateVersion` ties it to PM transactions.
   *
   * @returns Active formatting marks, or `null` when unavailable.
   */
  @cached
  get markState(): MarkState | null {
    void this._pmStateVersion;
    const view = this.#view;
    if (!view || !SCHEMAS[this.#schemaName].allowsMarks) {
      return null;
    }
    const { schema } = view.state;
    return {
      strong: hasMark(view.state, schema.marks.strong),
      em: hasMark(view.state, schema.marks.em),
      link: hasMark(view.state, schema.marks.link),
    };
  }

  /**
   * Stores the root element used for focus containment.
   *
   * @param element - Rich-text control root element.
   */
  @action
  registerRoot(element: HTMLElement): void {
    this.#rootEl = element;
  }

  /**
   * Lazily loads ProseMirror and mounts a constrained editor into the field,
   * seeded once from the current value. Bails if the field tore down while the
   * PM chunk was loading. `editable` tracks `readOnly`, so the editor goes inert
   * while the canvas owns the value.
   *
   * @param container - Element that hosts the ProseMirror view.
   * @returns A promise resolved after the editor mounts.
   */
  @action
  async mountEditor(container: HTMLElement): Promise<void> {
    const pm = await loadInlineRichEditor();
    // The field may have torn down while the PM chunk loaded.
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.#pm = pm;

    const variant = SCHEMAS[this.#schemaName];
    const schema = pm.createSchema(variant.extensions, false);
    const seedValue = this.liveValue;
    this.#committedValue = seedValue;
    const doc = pm.Node.fromJSON(schema, toDoc(seedValue));

    const plugins = [
      pm.history(),
      pm.keymap({
        "Mod-z": pm.undo,
        "Mod-y": pm.redo,
        "Shift-Mod-z": pm.redo,
        ...(variant.allowsMarks && {
          "Mod-b": pm.toggleMark(schema.marks.strong),
          "Mod-i": pm.toggleMark(schema.marks.em),
          "Mod-k": () => {
            this.enterLinkMode();
            return true;
          },
        }),
        // Paragraph fields soft-wrap on Enter; single-line fields commit and
        // blur (no newline) so Enter reads as "done".
        Enter: variant.allowsHardBreak
          ? insertHardBreak(schema)
          : () => {
              this.#view?.dom.blur();
              return true;
            },
        "Shift-Enter": variant.allowsHardBreak
          ? insertHardBreak(schema)
          : undefined,
      }),
    ];

    this.#view = new pm.EditorView(container, {
      state: pm.EditorState.create({ schema, doc, plugins }),
      attributes: { class: "wf-rich-text-editor" },
      // Inert while the canvas owns this value; `syncReadOnly` re-applies it
      // when the guard toggles (PM only re-reads `editable` on a prop update).
      editable: () => !this.readOnly,
      dispatchTransaction: (tr: InlineRichEditorTransaction) => {
        const view = this.#view;
        if (!view) {
          return;
        }
        view.updateState(view.state.apply(tr));
        this._pmStateVersion++;
      },
    });
  }

  /** Commits and destroys the mounted editor. */
  @action
  unmountEditor(): void {
    this.#commit();
    const view = this.#view;
    this.#view = null;
    view?.destroy();
    this.#savedLinkRange = null;
    this.linkMode = false;
  }

  /**
   * Re-applies the editor's editable state when the canvas-edit guard toggles.
   * ProseMirror only re-reads the `editable` prop on an update, so push one
   * when `readOnly` flips; also close any open link input on going inert.
   */
  @action
  syncReadOnly(): void {
    this.#view?.setProps({ editable: () => !this.readOnly });
    if (this.readOnly) {
      this.linkMode = false;
    }
  }

  /**
   * Re-seeds the editor when the value changes from OUTSIDE this editor (e.g.
   * the canvas committed an edit to the same arg) AND the editor isn't focused
   * — so an external change flows in without disrupting an edit in progress
   * here. No-op when the doc already matches. The editor remains its own source
   * of truth while focused (the user's keystrokes win until they blur).
   */
  @action
  reseed(): void {
    const view = this.#view;
    const pm = this.#pm;
    if (!view || !pm || view.hasFocus()) {
      return;
    }
    const next = this.liveValue;
    if (valuesEqual(toStorage(view.state.doc.toJSON()), next)) {
      return;
    }
    const doc = pm.Node.fromJSON(view.state.schema, toDoc(next));
    view.updateState(
      pm.EditorState.create({
        schema: view.state.schema,
        doc,
        plugins: view.state.plugins,
      })
    );
    this.#committedValue = next;
    this._pmStateVersion++;
  }

  /**
   * Commits on focus leaving the whole control (editor + toolbar + link
   * input). A focus move between the editor and a toolbar button stays inside
   * the root, so it does not commit — only leaving the control does.
   *
   * @param event - Focus event leaving an element in the control.
   */
  @action
  handleFocusOut(event: FocusEvent): void {
    const nextTarget =
      event.relatedTarget instanceof Node ? event.relatedTarget : null;
    if (this.readOnly || this.#rootEl?.contains(nextTarget)) {
      return;
    }
    this.#commit();
  }

  /**
   * Toggles `strong` / `em` over the current selection. Re-sets the selection
   * on the transaction so the highlight survives the focus bounce from
   * clicking a toolbar button.
   *
   * @param markName - Formatting mark to toggle.
   */
  @action
  toggleMark(markName: "strong" | "em"): void {
    const view = this.#view;
    const pm = this.#pm;
    if (!view || !pm) {
      return;
    }
    const markType = view.state.schema.marks[markName];
    const { from, to } = view.state.selection;
    if (!markType || from === to) {
      return;
    }
    const tr = view.state.tr;
    if (view.state.doc.rangeHasMark(from, to, markType)) {
      tr.removeMark(from, to, markType);
    } else {
      tr.addMark(from, to, markType.create());
    }
    tr.setSelection(pm.TextSelection.create(tr.doc, from, to));
    view.dispatch(tr);
    view.focus();
  }

  /**
   * Opens the inline URL input for the current non-empty selection, prefilled
   * with any existing link href. The saved range lets `applyLink` land on the
   * right positions after focus moves to the input.
   */
  @action
  enterLinkMode(): void {
    const view = this.#view;
    if (!view) {
      return;
    }
    const { from, to } = view.state.selection;
    if (from === to) {
      return;
    }
    this.#savedLinkRange = { from, to };
    this.linkValue =
      existingLinkHref(view.state, view.state.schema.marks.link) ?? "";
    this.linkMode = true;
  }

  /**
   * Updates the draft link URL.
   *
   * @param event - URL-input event.
   */
  @action
  setLinkValue(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.linkValue = event.currentTarget.value;
  }

  /** Applies the draft link URL. */
  @action
  applyLink(): void {
    this.#applyLinkMark(this.linkValue);
  }

  /** Removes the link mark from the saved range. */
  @action
  removeLink(): void {
    this.#applyLinkMark("");
  }

  /** Cancels link editing and restores editor focus. */
  @action
  cancelLink(): void {
    this.linkMode = false;
    this.#savedLinkRange = null;
    this.#view?.focus();
  }

  /** Commits the current document when it differs from the saved value. */
  #commit(): void {
    const view = this.#view;
    if (!view || this.readOnly) {
      return;
    }
    const next = toStorage(view.state.doc.toJSON());
    if (valuesEqual(next, this.#committedValue)) {
      return;
    }
    this.#committedValue = next;
    void this.args.custom.set(next);
  }

  /**
   * Applies (or, for an empty URL, removes) the link mark over the saved
   * range, then closes the inline input and returns focus to the editor.
   *
   * @param url - Link URL, or an empty string to remove the mark.
   */
  #applyLinkMark(url: string): void {
    const view = this.#view;
    const pm = this.#pm;
    const range = this.#savedLinkRange;
    if (view && pm && range) {
      const markType = view.state.schema.marks.link;
      const tr = view.state.tr.removeMark(range.from, range.to, markType);
      const trimmed = (url ?? "").trim();
      if (trimmed) {
        tr.addMark(range.from, range.to, markType.create({ href: trimmed }));
      }
      tr.setSelection(pm.TextSelection.create(tr.doc, range.from, range.to));
      view.dispatch(tr);
    }
    this.linkMode = false;
    this.#savedLinkRange = null;
    view?.focus();
  }

  <template>
    <div
      class="wireframe-inspector-rich-text"
      {{didInsert this.registerRoot}}
      {{on "focusout" this.handleFocusOut}}
    >
      {{! The editor stays mounted whether or not the canvas owns the value; the
        read-only flag just makes it inert (non-editable, dimmed, buttons
        disabled), so the rendered formatting and the layout never shift. }}
      {{#if this.showToolbar}}
        <div class="wireframe-inspector-rich-text__toolbar">
          <DButton
            class={{dConcatClass
              "wireframe-inspector-rich-text__btn"
              (if this.markState.strong "--active")
            }}
            @icon="bold"
            @disabled={{this.readOnly}}
            @action={{fn this.toggleMark "strong"}}
            @ariaLabel="wireframe.inspector.controls.bold"
          />
          <DButton
            class={{dConcatClass
              "wireframe-inspector-rich-text__btn"
              (if this.markState.em "--active")
            }}
            @icon="italic"
            @disabled={{this.readOnly}}
            @action={{fn this.toggleMark "em"}}
            @ariaLabel="wireframe.inspector.controls.italic"
          />
          <DButton
            class={{dConcatClass
              "wireframe-inspector-rich-text__btn"
              (if this.markState.link "--active")
            }}
            @icon="link"
            @disabled={{this.readOnly}}
            @action={{this.enterLinkMode}}
            @ariaLabel="wireframe.inspector.controls.link"
          />
        </div>
      {{/if}}

      {{#if this.linkMode}}
        <div class="wireframe-inspector-rich-text__link-input">
          <input
            type="url"
            value={{this.linkValue}}
            placeholder="https://"
            {{on "input" this.setLinkValue}}
          />
          <DButton
            class="btn-small"
            @icon="check"
            @action={{this.applyLink}}
            @ariaLabel="wireframe.inspector.controls.link_apply"
          />
          <DButton
            class="btn-small btn-flat"
            @icon="trash-can"
            @action={{this.removeLink}}
            @ariaLabel="wireframe.inspector.controls.link_remove"
          />
          <DButton
            class="btn-small btn-flat"
            @icon="xmark"
            @action={{this.cancelLink}}
            @ariaLabel="wireframe.inspector.controls.link_cancel"
          />
        </div>
      {{/if}}

      <div
        class={{dConcatClass
          "wireframe-inspector-rich-text__editor"
          (if this.readOnly "--disabled")
        }}
        {{didInsert this.mountEditor}}
        {{willDestroy this.unmountEditor}}
        {{didUpdate this.syncReadOnly this.readOnly}}
        {{didUpdate this.reseed this.liveValue}}
      ></div>
    </div>
  </template>
}

/**
 * Checks whether a string names a supported rich-text schema.
 *
 * @param value - Schema name supplied by argument metadata.
 * @returns Whether the schema is supported by this editor.
 */
function isRichTextSchemaName(value: string): value is RichTextSchemaName {
  return Object.hasOwn(SCHEMAS, value);
}
