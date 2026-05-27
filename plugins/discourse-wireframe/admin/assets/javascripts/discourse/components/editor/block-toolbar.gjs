// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

/**
 * Floating contextual toolbar shown above the currently-selected block.
 * Modelled on Gutenberg / Webflow / Puck's block-toolbar pattern: quick
 * actions (move up / move down / duplicate / delete) anchored to the
 * selected block, plus a `⋯` overflow menu reserved for less-common
 * affordances added in later sub-phases (wrap, convert, edit JSON).
 *
 * Mounted only when the chrome is selected. Positioning is via CSS
 * (`top: -34px; left: 0` against the chrome) — anchoring via
 * JavaScript would require popper/floating-ui, and our toolbar is
 * always relative to its host chrome anyway.
 *
 * Inline-format buttons (bold / italic / link) appear in this same
 * toolbar when the user has entered an inline-edit session on the
 * block AND has a non-empty text selection inside it. The controller
 * (`InlineEditController`) registers itself with the service as
 * `inlineEdit.controller`; we read its `markState` (a tracked-on-PM-transactions
 * getter) and call its commands. Co-locating the inline formatters
 * with the block actions avoids the focus / scroll-tracking problems
 * a separately-floating bubble menu had.
 *
 * Inline-format buttons use `@preventFocus={{true}}` on `DButton` so
 * the mousedown's default focus shift is suppressed — ProseMirror
 * keeps focus and the selection highlight stays visible while the
 * mark applies. The block-action buttons (move/duplicate/delete) don't
 * need this because they have no PM selection to preserve.
 */
export default class BlockToolbar extends Component {
  @service wireframe;

  /**
   * Working value of the URL input while a field-editor slot is
   * active. Seeded from `wireframe.fieldEditor.value` when the input
   * mounts (see `seedFieldEditorValue`). The slot's `value` is the
   * INITIAL value; this is the live edit-in-progress string the user
   * is typing.
   */
  @tracked _editorValue = "";

  get canMoveUp() {
    return this.wireframe.canMoveSelectedUp;
  }

  get canMoveDown() {
    return this.wireframe.canMoveSelectedDown;
  }

  /**
   * `true` when this toolbar should expose the "expand for editing"
   * toggle. Shown for `wf:layout` blocks whose `autoCollapse` isn't
   * `"never"` — i.e. the layout could actually collapse at narrow
   * widths, so an override has something to override.
   *
   * @returns {boolean}
   */
  get canForceExpand() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const located = this.wireframe._findEntryAndOutletSync(this.args.blockKey);
    const entry = located?.entry;
    if (entry?.block !== "wf:layout") {
      return false;
    }
    return (entry.args?.autoCollapse ?? "default") !== "never";
  }

  /**
   * Mirrors the editor service's force-expand state for this block.
   *
   * @returns {boolean}
   */
  get isForceExpanded() {
    return this.wireframe.isForceExpanded(this.args.blockKey);
  }

  /**
   * The active inline-edit controller, or `null` when no inline
   * session is open.
   */
  get inlineController() {
    return this.wireframe.inlineEdit.controller;
  }

  /**
   * Whether the inline-format buttons should be visible. Requires:
   *   - an active inline-edit session on THIS block,
   *   - a non-empty PM selection that the schema marks can apply to.
   *
   * @returns {boolean}
   */
  get showInlineFormat() {
    return (
      !!this.inlineController &&
      this.wireframe.inlineEdit.blockKey === this.args.blockKey &&
      this.inlineController.markState !== null
    );
  }

  get markState() {
    return this.inlineController?.markState;
  }

  /**
   * `true` when the toolbar should render its URL-edit surface for
   * the inline rich-text link mark — i.e. PM has entered link-mark
   * mode (`enterLinkMode` in `inline-edit-controller.gjs`), which
   * populates `wireframe.fieldEditor` with `kind === "url"`.
   *
   * Block-arg URL edits (e.g. a button's `href`) are no longer routed
   * through here — those open an anchored `LinkEditPopover` next to
   * the link element instead. The rich-text link mark has no DOM
   * anchor of its own, so it stays on the toolbar.
   */
  get isUrlFieldEditing() {
    return this.wireframe.fieldEditor?.kind === "url";
  }

  @action
  toggleForceExpand() {
    this.wireframe.toggleForceExpand(this.args.blockKey);
  }

  @action
  moveUp() {
    this.wireframe.moveBlockUp(this.args.blockKey);
  }

  @action
  moveDown() {
    this.wireframe.moveBlockDown(this.args.blockKey);
  }

  @action
  duplicate() {
    this.wireframe.duplicateBlock(this.args.blockKey);
  }

  @action
  remove() {
    this.wireframe.removeBlock(this.args.blockKey);
  }

  @action
  toggleBold() {
    this.inlineController?.toggleMark("strong");
  }

  @action
  toggleItalic() {
    this.inlineController?.toggleMark("em");
  }

  @action
  startLinkEdit() {
    this.inlineController?.enterLinkMode();
  }

  @action
  applyFieldEditor() {
    this.wireframe.fieldEditor?.apply?.(this._editorValue);
  }

  @action
  removeFieldEditor() {
    this.wireframe.fieldEditor?.remove?.();
  }

  @action
  cancelFieldEditor() {
    this.wireframe.fieldEditor?.cancel?.();
  }

  @action
  onUrlInput(event) {
    this._editorValue = event.target.value;
  }

  @action
  onUrlKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.applyFieldEditor();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelFieldEditor();
    }
  }

  /**
   * Seed the local working value from the slot's initial value when
   * the input mounts (a new slot opens). The slot's `value` is the
   * current arg / mark value at edit-start; `_editorValue` is the
   * live in-progress edit. Auto-selects so typing replaces.
   */
  @action
  seedFieldEditorValue(element) {
    this._editorValue = this.wireframe.fieldEditor?.value ?? "";
    element.focus();
    element.select();
  }

  <template>
    <div class="wireframe-block-toolbar" role="toolbar">
      {{#if this.isUrlFieldEditing}}
        {{! eslint-disable-next-line ember/template-no-nested-interactive }}
        <input
          type="url"
          class="wireframe-block-toolbar__url-input"
          placeholder="https://..."
          value={{this._editorValue}}
          {{didInsert this.seedFieldEditorValue}}
          {{on "input" this.onUrlInput}}
          {{on "keydown" this.onUrlKeydown}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="check"
          @title="wireframe.canvas.toolbar.link_apply"
          @ariaLabel="wireframe.canvas.toolbar.link_apply"
          @action={{this.applyFieldEditor}}
          @preventFocus={{true}}
        />
        {{#if this.wireframe.fieldEditor.remove}}
          <DButton
            class="btn-flat wireframe-block-toolbar__btn"
            @icon="link-slash"
            @title="wireframe.canvas.toolbar.link_remove"
            @ariaLabel="wireframe.canvas.toolbar.link_remove"
            @action={{this.removeFieldEditor}}
            @preventFocus={{true}}
          />
        {{/if}}
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="xmark"
          @title="wireframe.canvas.toolbar.link_cancel"
          @ariaLabel="wireframe.canvas.toolbar.link_cancel"
          @action={{this.cancelFieldEditor}}
          @preventFocus={{true}}
        />
      {{else}}
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="arrow-up"
          @title="wireframe.canvas.toolbar.move_up"
          @ariaLabel="wireframe.canvas.toolbar.move_up"
          @disabled={{if this.canMoveUp false true}}
          @action={{this.moveUp}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="arrow-down"
          @title="wireframe.canvas.toolbar.move_down"
          @ariaLabel="wireframe.canvas.toolbar.move_down"
          @disabled={{if this.canMoveDown false true}}
          @action={{this.moveDown}}
        />
        <DButton
          class="btn-flat wireframe-block-toolbar__btn"
          @icon="copy"
          @title="wireframe.canvas.toolbar.duplicate"
          @ariaLabel="wireframe.canvas.toolbar.duplicate"
          @action={{this.duplicate}}
        />
        {{#if this.canForceExpand}}
          <DButton
            class={{if
              this.isForceExpanded
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon={{if
              this.isForceExpanded
              "down-left-and-up-right-to-center"
              "up-right-and-down-left-from-center"
            }}
            @title={{if
              this.isForceExpanded
              "wireframe.canvas.toolbar.collapse_for_preview"
              "wireframe.canvas.toolbar.expand_for_editing"
            }}
            @ariaLabel={{if
              this.isForceExpanded
              "wireframe.canvas.toolbar.collapse_for_preview"
              "wireframe.canvas.toolbar.expand_for_editing"
            }}
            @ariaPressed={{this.isForceExpanded}}
            @action={{this.toggleForceExpand}}
          />
        {{/if}}
        {{#if this.showInlineFormat}}
          <span
            class="wireframe-block-toolbar__separator"
            aria-hidden="true"
          ></span>
          <DButton
            class={{if
              this.markState.strong
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="bold"
            @title="wireframe.canvas.toolbar.bold"
            @ariaLabel="wireframe.canvas.toolbar.bold"
            @ariaPressed={{this.markState.strong}}
            @action={{this.toggleBold}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.em
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="italic"
            @title="wireframe.canvas.toolbar.italic"
            @ariaLabel="wireframe.canvas.toolbar.italic"
            @ariaPressed={{this.markState.em}}
            @action={{this.toggleItalic}}
            @preventFocus={{true}}
          />
          <DButton
            class={{if
              this.markState.link
              "btn-flat wireframe-block-toolbar__btn --active"
              "btn-flat wireframe-block-toolbar__btn"
            }}
            @icon="link"
            @title="wireframe.canvas.toolbar.link"
            @ariaLabel="wireframe.canvas.toolbar.link"
            @ariaPressed={{this.markState.link}}
            @action={{this.startLinkEdit}}
            @preventFocus={{true}}
          />
        {{/if}}
        <span class="toolbar-separator" aria-hidden="true"></span>
        <DButton
          class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__btn--danger"
          @icon="trash-can"
          @title="wireframe.canvas.toolbar.delete"
          @ariaLabel="wireframe.canvas.toolbar.delete"
          @action={{this.remove}}
        />
      {{/if}}
    </div>
  </template>
}
