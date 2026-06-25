// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";

// Quick-pick copy counts offered by the Duplicate button's dropdown, alongside
// a custom field. Stamping out a row of identical cards is then one gesture
// instead of N clicks.
const DUPLICATE_PRESETS = [2, 3, 5, 10];

/**
 * Floating contextual bar shown above each block chrome. Two regions
 * sit inside one rounded "tab" anchored to the chrome's top-left edge:
 *
 *   1. Handle region — grip icon + display name + drag-source
 *      modifier. Replaces the standalone block-handle badge so the
 *      block's identity stays visible whenever the bar is. Rendered
 *      for movable blocks and composite parts; the outlet root has no
 *      handle (its identity lives in the always-on outlet badge), so
 *      its toolbar carries only its selection actions.
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

  /**
   * Copy count for the Duplicate dropdown's custom field. Read from the
   * template (the number input + its apply button), so it stays unprefixed.
   */
  @tracked customDuplicateCount = 2;

  /** FloatKit menu API for the Duplicate dropdown, captured so a pick can close it. */
  #duplicateMenu = null;

  get canMoveUp() {
    return this.wireframe.canMoveSelectedUp;
  }

  get canMoveDown() {
    return this.wireframe.canMoveSelectedDown;
  }

  /**
   * Whether the block's siblings run horizontally (a tabs / carousel parent, or
   * a `layout` in row mode), so the reorder arrows point left/right rather than
   * up/down. The underlying move is the same "earlier / later sibling" in both
   * orientations — only the icons and labels change.
   *
   * @returns {boolean}
   */
  get isHorizontalMove() {
    return this.args.moveAxis === "horizontal";
  }

  /** @returns {string} Icon for moving to the earlier sibling. */
  get moveBackIcon() {
    return this.isHorizontalMove ? "arrow-left" : "arrow-up";
  }

  /** @returns {string} Icon for moving to the later sibling. */
  get moveForwardIcon() {
    return this.isHorizontalMove ? "arrow-right" : "arrow-down";
  }

  /** @returns {string} i18n key for the earlier-sibling move. */
  get moveBackLabel() {
    return this.isHorizontalMove
      ? "wireframe.canvas.toolbar.move_left"
      : "wireframe.canvas.toolbar.move_up";
  }

  /** @returns {string} i18n key for the later-sibling move. */
  get moveForwardLabel() {
    return this.isHorizontalMove
      ? "wireframe.canvas.toolbar.move_right"
      : "wireframe.canvas.toolbar.move_down";
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
  registerDuplicateMenu(api) {
    this.#duplicateMenu = api;
  }

  @action
  updateCustomDuplicateCount(event) {
    // Clamp to a sane positive integer; an empty/invalid field falls back to 1.
    this.customDuplicateCount = Math.max(
      1,
      parseInt(event.target.value, 10) || 1
    );
  }

  @action
  async duplicateTimes(count) {
    await this.#duplicateMenu?.close();
    this.wireframe.duplicateBlock(this.args.blockKey, count);
  }

  @action
  remove() {
    this.wireframe.removeBlock(this.args.blockKey);
  }

  /**
   * `true` when this toolbar belongs to a synthesized composite part (which
   * has no persisted entry). Structural actions — move, duplicate, delete,
   * drag-to-reorder — are meaningless for a part, so the toolbar hides them.
   *
   * @returns {boolean}
   */
  get isPart() {
    return isPartKey(this.args.blockKey);
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

        The outlet root is a page region, not a movable block — its handle
        carries no drag source and reads as the outlet identity: the cube
        icon, the outlet name, and an inner status chip (Editing / Published /
        Default). This handle is the always-on badge above the region (kept
        visible by CSS), so the outlet stays labelled without hovering. }}
      {{#if @isOutletRoot}}
        <span
          class="wireframe-block-toolbar__handle wireframe-block-toolbar__handle--outlet"
          title={{@displayName}}
        >
          {{dIcon "cubes"}}
          <span>{{@displayName}}</span>
          {{#if @showOutletStatus}}
            <span
              class={{dConcatClass
                "wireframe-block-toolbar__status"
                (concat "--" (if @isOutletEditing "editing" @outletState))
              }}
            >{{if
                @isOutletEditing
                (i18n "wireframe.outlet.editing")
                (i18n (concat "wireframe.outlet.state." @outletState))
              }}</span>
          {{/if}}
        </span>
      {{else if this.isPart}}
        {{! A composite part isn't a movable block — its handle reads as a
          part (dashed icon + name) and carries no drag source. }}
        <span class="wireframe-block-toolbar__handle" title={{@displayName}}>
          {{dIcon "circle-dashed"}}
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
          {{! The displayTitle arg carries a fuller name (e.g. a tab's own
              label) for a block shown by ordinal; absent for ordinary blocks.
              The displayChip arg, when present, is the block's position within
              an ordinal-naming container (a tabs panel, a carousel slide),
              shown as a chip beside the name. }}
          <span title={{@displayTitle}}>{{@displayName}}</span>
          {{#if @displayChip}}
            <span
              class="wireframe-block-toolbar__ordinal"
            >{{@displayChip}}</span>
          {{/if}}
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
          {{#unless (or @isOutletRoot this.isPart)}}
            <DButton
              class="btn-flat wireframe-block-toolbar__btn"
              @icon={{this.moveBackIcon}}
              @title={{this.moveBackLabel}}
              @ariaLabel={{this.moveBackLabel}}
              @disabled={{if this.canMoveUp false true}}
              @action={{this.moveUp}}
            />
            <DButton
              class="btn-flat wireframe-block-toolbar__btn"
              @icon={{this.moveForwardIcon}}
              @title={{this.moveForwardLabel}}
              @ariaLabel={{this.moveForwardLabel}}
              @disabled={{if this.canMoveDown false true}}
              @action={{this.moveDown}}
            />
            <DComboButton class="wireframe-block-toolbar__duplicate" as |combo|>
              <combo.Button
                class="btn-flat wireframe-block-toolbar__btn"
                @icon="copy"
                @title="wireframe.canvas.toolbar.duplicate"
                @ariaLabel="wireframe.canvas.toolbar.duplicate"
                @action={{this.duplicate}}
              />
              <combo.Menu
                class="btn-flat wireframe-block-toolbar__btn"
                @identifier="wireframe-duplicate-count"
                @title={{i18n "wireframe.canvas.toolbar.duplicate_count"}}
                @ariaLabel={{i18n "wireframe.canvas.toolbar.duplicate_count"}}
                @onRegisterApi={{this.registerDuplicateMenu}}
              >
                <DDropdownMenu as |dropdown|>
                  {{#each DUPLICATE_PRESETS as |n|}}
                    <dropdown.item>
                      <DButton
                        class="btn-flat"
                        @translatedLabel={{i18n
                          "wireframe.canvas.toolbar.duplicate_n"
                          count=n
                        }}
                        @action={{fn this.duplicateTimes n}}
                      />
                    </dropdown.item>
                  {{/each}}
                  <dropdown.item
                    class="wireframe-block-toolbar__duplicate-custom"
                  >
                    {{! The dropdown content renders in a FloatKit portal, so
                      this input isn't actually nested inside the toolbar in the
                      DOM — the lexical nesting is a false positive. }}
                    {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                    <input
                      type="number"
                      min="1"
                      aria-label={{i18n
                        "wireframe.canvas.toolbar.duplicate_custom"
                      }}
                      value={{this.customDuplicateCount}}
                      {{on "input" this.updateCustomDuplicateCount}}
                    />
                    <DButton
                      class="btn-flat"
                      @label="wireframe.canvas.toolbar.duplicate_apply"
                      @action={{fn
                        this.duplicateTimes
                        this.customDuplicateCount
                      }}
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </combo.Menu>
            </DComboButton>
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
          {{#unless (or @isOutletRoot this.isPart)}}
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
