// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";
import toolbarFit from "../../modifiers/toolbar-fit";

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
 * On a narrow block the bar would overflow, so its collapsible (structural)
 * actions fold into a hamburger as space runs out. The `toolbar-fit` modifier
 * registers this bar's chrome with the `wireframe-toolbar-fit` coordinator,
 * which measures the chrome's width and writes a `data-wf-toolbar-fit` tier on
 * it; the stylesheet keys off that to swap the inline action row for the
 * hamburger and, when even that doesn't fit, drop the handle's name to its
 * tooltip. The inline buttons and the hamburger menu render from one
 * `actionItems` descriptor list, so the two can't drift.
 *
 * Inline-format buttons (bold / italic / link) appear when the user
 * has entered an inline-edit session on this block AND has a non-empty
 * text selection inside it. The controller (`InlineEditController`)
 * registers itself with the service as `wireframeInlineEdit.controller`; we
 * read its `markState` (a tracked-on-PM-transactions getter) and call
 * its commands.
 *
 * Inline-format buttons use `@preventFocus={{true}}` on `DButton` so
 * the mousedown's default focus shift is suppressed — ProseMirror
 * keeps focus and the selection highlight stays visible while the
 * mark applies. They are deliberately NOT collapsed into the hamburger:
 * a menu item click can't preserve the ProseMirror selection the way
 * `@preventFocus` does, so they stay inline whenever they show. The
 * block-action buttons (move/duplicate/delete) don't need this because
 * they have no PM selection to preserve.
 */
export default class BlockToolbar extends Component {
  @service wireframe;
  @service wireframeBlockMutations;
  @service wireframeForceExpand;
  @service wireframeInlineEdit;
  @service wireframeRevision;

  /**
   * Working value of the URL input while a field-editor slot is
   * active. Seeded from `wireframeInlineEdit.fieldEditor.value` when the input
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
    const _v = this.wireframeRevision.version;
    const located = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    );
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
    return this.wireframeForceExpand.isForceExpanded(this.args.blockKey);
  }

  /**
   * The active inline-edit controller, or `null` when no inline
   * session is open.
   */
  get inlineController() {
    return this.wireframeInlineEdit.controller;
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
      this.wireframeInlineEdit.blockKey === this.args.blockKey &&
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
   * populates `wireframeInlineEdit.fieldEditor` with `kind === "url"`.
   *
   * Block-arg URL edits (e.g. a button's `href`) are no longer routed
   * through here — those open an anchored `LinkEditPopover` next to
   * the link element instead. The rich-text link mark has no DOM
   * anchor of its own, so it stays on the toolbar.
   */
  get isUrlFieldEditing() {
    return this.wireframeInlineEdit.fieldEditor?.kind === "url";
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
   * `true` for an ordinary movable block — neither the outlet root (a page
   * region) nor a composite part. Only movable blocks carry the structural
   * actions that fold into the hamburger, so only they collapse.
   *
   * @returns {boolean}
   */
  get isCollapsible() {
    return !this.args.isOutletRoot && !this.isPart;
  }

  /**
   * `true` when this bar should be width-tracked for collapse: it's the
   * selected block, it's a movable block (the only kind with a foldable action
   * set), and it isn't in the URL-edit sub-mode (which renders its own inline
   * surface that doesn't collapse).
   *
   * @returns {boolean}
   */
  get fitActive() {
    return (
      this.args.isSelected && this.isCollapsible && !this.isUrlFieldEditing
    );
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
    const _v = this.wireframeRevision.version;
    return this.wireframe.layoutQuery.isComposedComposite(this.args.blockKey);
  }

  /**
   * The single, ordered source of truth for the bar's collapsible (structural)
   * actions. Both the inline action row and the hamburger menu render from this
   * list, so they can never drift. Each descriptor is one of:
   *
   *   - a plain icon button: `{ id, group, icon, title, action, disabled?,
   *     active?, danger? }`,
   *   - the duplicate split-button: `{ id, group, type: "duplicate" }`, which
   *     both renderers special-case.
   *
   * `separatorBefore` is computed from `group` transitions so the inline row
   * reproduces the visual grouping. Outlet roots and parts omit the structural
   * actions (move/duplicate/detach/delete), leaving only whatever applies (e.g.
   * the force-expand toggle on a layout), and never collapse.
   *
   * @returns {Array<Object>}
   */
  @cached
  get actionItems() {
    const items = [];

    if (this.isCollapsible) {
      items.push({
        id: "move-back",
        group: "primary",
        icon: this.moveBackIcon,
        title: this.moveBackLabel,
        disabled: !this.canMoveUp,
        action: this.moveUp,
      });
      items.push({
        id: "move-forward",
        group: "primary",
        icon: this.moveForwardIcon,
        title: this.moveForwardLabel,
        disabled: !this.canMoveDown,
        action: this.moveDown,
      });
      items.push({ id: "duplicate", group: "primary", type: "duplicate" });
      if (this.canDetach) {
        items.push({
          id: "detach",
          group: "primary",
          icon: "object-group",
          title: "wireframe.canvas.toolbar.detach",
          action: this.detach,
        });
      }
    }

    if (this.canForceExpand) {
      items.push({
        id: "force-expand",
        group: "primary",
        icon: this.isForceExpanded
          ? "down-left-and-up-right-to-center"
          : "up-right-and-down-left-from-center",
        title: this.isForceExpanded
          ? "wireframe.canvas.toolbar.collapse_for_preview"
          : "wireframe.canvas.toolbar.expand_for_editing",
        active: this.isForceExpanded,
        action: this.toggleForceExpand,
      });
    }

    if (this.args.canFillImage) {
      items.push({
        id: "image-fill",
        group: "image",
        icon: "expand",
        title: "wireframe.canvas.toolbar.image_fill",
        action: this.args.onFillImage,
      });
    }
    if (this.args.canResetImage) {
      items.push({
        id: "image-reset",
        group: "image",
        icon: "arrows-rotate",
        title: "wireframe.canvas.toolbar.image_reset",
        action: this.args.onResetImage,
      });
    }

    if (this.isCollapsible) {
      items.push({
        id: "delete",
        group: "danger",
        icon: "trash-can",
        title: "wireframe.canvas.toolbar.delete",
        danger: true,
        action: this.remove,
      });
    }

    // A separator marks each group boundary, reproducing the inline grouping.
    let prevGroup = null;
    for (const item of items) {
      item.separatorBefore = prevGroup !== null && item.group !== prevGroup;
      prevGroup = item.group;
    }

    return items;
  }

  /**
   * A string that changes whenever the bar's rendered content changes width:
   * the handle's name / ordinal, the URL-edit and inline-format sub-modes, and
   * the identity / disabled / active / icon of every action. The `toolbar-fit`
   * modifier reads this so it re-measures on a content change; a plain resize
   * is caught by the coordinator's observer instead.
   *
   * @returns {string}
   */
  get fitFingerprint() {
    const parts = [
      this.args.displayName,
      this.args.displayChip,
      this.isUrlFieldEditing ? "url" : "",
      this.showInlineFormat ? "fmt" : "",
    ];
    for (const item of this.actionItems) {
      parts.push(
        `${item.id}:${item.disabled ? 1 : 0}:${item.active ? 1 : 0}:${item.icon ?? ""}`
      );
    }
    return parts.join("|");
  }

  @action
  toggleForceExpand() {
    this.wireframeForceExpand.toggleForceExpand(this.args.blockKey);
  }

  @action
  moveUp() {
    this.wireframeBlockMutations.moveBlockUp(this.args.blockKey);
  }

  @action
  moveDown() {
    this.wireframeBlockMutations.moveBlockDown(this.args.blockKey);
  }

  @action
  duplicate() {
    this.wireframeBlockMutations.duplicateBlock(this.args.blockKey);
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
    this.wireframeBlockMutations.duplicateBlock(this.args.blockKey, count);
  }

  @action
  remove() {
    this.wireframeBlockMutations.removeBlock(this.args.blockKey);
  }

  @action
  detach() {
    this.wireframe.detachSelectedComposite();
  }

  /**
   * Runs a hamburger-menu action, closing the menu first so the action (which
   * may unmount this toolbar, e.g. delete) doesn't fire against a torn-down
   * menu portal.
   *
   * @param {() => void} actionFn - The descriptor's action.
   * @param {() => void} [close] - The menu's close callback.
   */
  @action
  invokeFromMenu(actionFn, close) {
    close?.();
    actionFn?.();
  }

  /**
   * Duplicates the block N times from the hamburger menu, closing the menu first.
   *
   * @param {number} count - How many copies to make.
   * @param {() => void} [close] - The menu's close callback.
   */
  @action
  duplicateFromMenu(count, close) {
    close?.();
    this.wireframeBlockMutations.duplicateBlock(this.args.blockKey, count);
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
    this.wireframeInlineEdit.fieldEditor?.apply?.(this.editorValue);
  }

  @action
  removeFieldEditor() {
    this.wireframeInlineEdit.fieldEditor?.remove?.();
  }

  @action
  cancelFieldEditor() {
    this.wireframeInlineEdit.fieldEditor?.cancel?.();
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
    this.editorValue = this.wireframeInlineEdit.fieldEditor?.value ?? "";
    element.focus();
    element.select();
  }

  @action
  startDrag({ source }) {
    this.wireframe.startDrag(source.data);
  }

  <template>
    <div
      class="wireframe-block-toolbar"
      role="toolbar"
      {{toolbarFit
        chromeEl=@chromeEl
        active=this.fitActive
        fingerprint=this.fitFingerprint
      }}
    >
      {{! Handle region — always present so block identity stays
        visible whenever the bar is shown, and so the drag-source
        modifier's registration is stable across hover transitions.
        The drag-preview arg is the chrome's outer div (passed in by
        BlockChrome via the chromeEl arg) so the browser shows a
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
        {{! The handle title carries the block name (not a drag hint) so the
            identity stays discoverable at the Narrower tier, where the name
            text is dropped and only the grip + hamburger remain. The grip icon
            and grab cursor still signal that it drags. }}
        <span
          class="wireframe-block-toolbar__handle"
          title={{@displayName}}
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
          {{#if this.wireframeInlineEdit.fieldEditor.remove}}
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
          {{! Collapsible structural actions. The inline row and the hamburger
              below render from the same actions list. CSS swaps which is in
              flow via the chrome's fit data attribute; whichever is off-tier
              sits absolutely positioned and hidden but still measurable. }}
          <div class="wireframe-block-toolbar__actions">
            {{#each this.actionItems as |item|}}
              {{#if item.separatorBefore}}
                <span
                  class="wireframe-block-toolbar__separator"
                  aria-hidden="true"
                ></span>
              {{/if}}
              {{#if (eq item.type "duplicate")}}
                <DComboButton
                  class="wireframe-block-toolbar__duplicate"
                  as |combo|
                >
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
                    @ariaLabel={{i18n
                      "wireframe.canvas.toolbar.duplicate_count"
                    }}
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
              {{else}}
                <DButton
                  class={{dConcatClass
                    "btn-flat"
                    "wireframe-block-toolbar__btn"
                    (if item.active "--active")
                    (if item.danger "wireframe-block-toolbar__btn--danger")
                  }}
                  @icon={{item.icon}}
                  @title={{item.title}}
                  @ariaLabel={{item.title}}
                  @disabled={{item.disabled}}
                  @ariaPressed={{item.active}}
                  @action={{item.action}}
                />
              {{/if}}
            {{/each}}
          </div>

          {{! Hamburger — the collapsed home for the actions above. Only movable
              blocks collapse, so outlet roots and parts render no hamburger
              (their few actions stay inline). The menu renders the same actions
              list as text items. }}
          {{#if this.isCollapsible}}
            <DMenu
              class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__more"
              @identifier="wireframe-toolbar-more"
              @icon="bars"
              @placement="bottom-start"
              @title="wireframe.canvas.toolbar.more"
              @ariaLabel="wireframe.canvas.toolbar.more"
              aria-haspopup="menu"
            >
              <:content as |args|>
                <DDropdownMenu as |dropdown|>
                  {{#each this.actionItems as |item|}}
                    {{#if (eq item.type "duplicate")}}
                      <dropdown.item>
                        <DButton
                          class="btn-flat"
                          @icon="copy"
                          @label="wireframe.canvas.toolbar.duplicate"
                          @action={{fn
                            this.invokeFromMenu
                            this.duplicate
                            args.close
                          }}
                        />
                      </dropdown.item>
                      {{#each DUPLICATE_PRESETS as |n|}}
                        <dropdown.item>
                          <DButton
                            class="btn-flat"
                            @translatedLabel={{i18n
                              "wireframe.canvas.toolbar.duplicate_n"
                              count=n
                            }}
                            @action={{fn this.duplicateFromMenu n args.close}}
                          />
                        </dropdown.item>
                      {{/each}}
                    {{else}}
                      <dropdown.item>
                        <DButton
                          class={{dConcatClass
                            "btn-flat"
                            (if item.active "--active")
                            (if
                              item.danger "wireframe-block-toolbar__btn--danger"
                            )
                          }}
                          @icon={{item.icon}}
                          @translatedLabel={{i18n item.title}}
                          @disabled={{item.disabled}}
                          @action={{fn
                            this.invokeFromMenu
                            item.action
                            args.close
                          }}
                        />
                      </dropdown.item>
                    {{/if}}
                  {{/each}}
                </DDropdownMenu>
              </:content>
            </DMenu>
          {{/if}}

          {{! Inline-format buttons stay inline whenever they show (never
              collapse) so the FloatKit menu can't steal the ProseMirror
              selection. The preventFocus arg keeps PM focused while a mark
              applies. }}
          {{#if this.showInlineFormat}}
            <div class="wireframe-block-toolbar__format">
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
            </div>
          {{/if}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
