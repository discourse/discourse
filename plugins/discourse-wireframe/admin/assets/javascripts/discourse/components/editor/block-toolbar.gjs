// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";

/**
 * Floating contextual bar shown above each block chrome. Two regions
 * sit inside one rounded "tab" anchored to the chrome's top-left edge:
 *
 *   1. Handle region (always rendered) — grip icon + display name +
 *      drag-source modifier. Replaces the standalone block-handle
 *      badge so the block's identity stays visible whenever the bar
 *      is.
 *   2. Action region (rendered when `@isSelected`) — move up / down,
 *      duplicate, optional force-expand toggle, inline-format
 *      buttons, delete.
 *
 * The bar is mounted whenever the chrome is rendered; CSS reveals it
 * on hover (innermost only) or on selection. Positioning is via CSS
 * (`bottom: 100%; left: ~-border-width` against the chrome) — same
 * anchor as the outlet badge.
 *
 * Inline-format buttons (bold / italic / link) appear when the user
 * has entered an inline-edit session on this block AND has a non-empty
 * text selection inside it. The controller (`InlineEditController`)
 * registers itself with the service as `inlineEdit.controller`; we
 * read its `markState` (a tracked-on-PM-transactions getter) and call
 * its commands.
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
  @tracked editorValue = "";

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
    const located = this.wireframe.findEntryAndOutletSync(this.args.blockKey);
    const entry = located?.entry;
    if (entry?.block !== "layout") {
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

  /**
   * `true` when this block is a composed composite (renders a code-defined
   * `parts` composition) and can therefore be detached into explicit,
   * freely-editable children.
   *
   * @returns {boolean}
   */
  get canDetach() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    return this.wireframe.isComposedComposite(this.args.blockKey);
  }

  @action
  detach() {
    this.wireframe.detachSelectedComposite();
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
    this.wireframe.fieldEditor?.apply?.(this.editorValue);
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
    this.editorValue = event.target.value;
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
   * current arg / mark value at edit-start; `editorValue` is the
   * live in-progress edit. Auto-selects so typing replaces.
   */
  @action
  seedFieldEditorValue(element) {
    this.editorValue = this.wireframe.fieldEditor?.value ?? "";
    element.focus();
    element.select();
  }

  @action
  startDrag({ source }) {
    this.wireframe.startDrag(source.data);
  }

  <template>
    <div class="wireframe-block-toolbar" role="toolbar">
      {{! Handle region — always present so block identity stays
        visible whenever the bar is shown, and so the drag-source
        modifier's registration is stable across hover transitions.
        `dragPreview` is the chrome's outer div (passed in by
        BlockChrome via `@chromeEl`) so the browser shows a
        translucent copy of the actual block during the drag instead
        of the small handle tab.

        The outlet root is a page region, not a movable block — its
        handle drops the drag source and reads as the outlet (cube
        icon, outlet name) rather than a grip. }}
      {{#if @isOutletRoot}}
        <span class="wireframe-block-toolbar__handle" title={{@displayName}}>
          {{dIcon "cubes"}}
          <span>{{@displayName}}</span>
        </span>
      {{else}}
        <span
          class="wireframe-block-toolbar__handle"
          title={{i18n "wireframe.canvas.drag_handle_title"}}
          {{dDragAndDropSource
            type="wf-block"
            data=(hash blockKey=@blockKey outletName=@outletName)
            dragPreview=@chromeEl
            onDragStart=this.startDrag
            onDrop=this.wireframe.endDrag
          }}
        >
          {{dIcon "grip-lines"}}
          <span>{{@displayName}}</span>
        </span>
      {{/if}}

      {{#if @isSelected}}
        {{#if this.isUrlFieldEditing}}
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <input
            type="url"
            class="wireframe-block-toolbar__url-input"
            placeholder="https://..."
            value={{this.editorValue}}
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
          {{! Move / duplicate / delete don't apply to the outlet root —
            a page region can't be reordered, copied, or removed. }}
          {{#unless @isOutletRoot}}
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
            {{#if this.canDetach}}
              <DButton
                class="btn-flat wireframe-block-toolbar__btn"
                @icon="object-group"
                @title="wireframe.canvas.toolbar.detach"
                @ariaLabel="wireframe.canvas.toolbar.detach"
                @action={{this.detach}}
              />
            {{/if}}
          {{/unless}}
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
          {{#if (or @canFillImage @canResetImage)}}
            <span
              class="wireframe-block-toolbar__separator"
              aria-hidden="true"
            ></span>
            {{#if @canFillImage}}
              <DButton
                class="btn-flat wireframe-block-toolbar__btn"
                @icon="expand"
                @title="wireframe.canvas.toolbar.image_fill"
                @ariaLabel="wireframe.canvas.toolbar.image_fill"
                @action={{@onFillImage}}
              />
            {{/if}}
            {{#if @canResetImage}}
              <DButton
                class="btn-flat wireframe-block-toolbar__btn"
                @icon="arrows-rotate"
                @title="wireframe.canvas.toolbar.image_reset"
                @ariaLabel="wireframe.canvas.toolbar.image_reset"
                @action={{@onResetImage}}
              />
            {{/if}}
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
          {{#unless @isOutletRoot}}
            <span
              class="wireframe-block-toolbar__separator"
              aria-hidden="true"
            ></span>
            <DButton
              class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__btn--danger"
              @icon="trash-can"
              @title="wireframe.canvas.toolbar.delete"
              @ariaLabel="wireframe.canvas.toolbar.delete"
              @action={{this.remove}}
            />
          {{/unless}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
