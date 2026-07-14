// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dFit from "discourse/ui-kit/modifiers/d-fit";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import {
  computeTier,
  FIT_TIERS,
} from "discourse/plugins/discourse-wireframe/discourse/lib/toolbar-fit-tier";

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
 *   2. Action region (rendered when `@isSelected`) — select parent,
 *      move up / down, duplicate, optional force-expand toggle,
 *      inline-format buttons, delete.
 *
 * The bar is mounted whenever the chrome is rendered; CSS reveals it
 * on hover (innermost only) or on selection. Positioning is via CSS
 * (`bottom: 100%; left: ~-border-width` against the chrome) — same
 * anchor as the outlet badge.
 *
 * On a narrow block the bar would overflow, so its collapsible (structural)
 * actions fold into an overflow menu as space runs out. The shared `d-fit`
 * modifier registers this bar's chrome with the fit coordinator, which measures
 * the chrome's width and writes a `data-wf-toolbar-fit` tier on it; the
 * stylesheet keys off that to swap the inline action row for the overflow menu
 * and, when even that doesn't fit, drop the handle's name to its tooltip. The
 * inline buttons and the overflow menu render from one `actionItems` descriptor
 * list, so the two can't drift.
 *
 * Inline-format buttons (bold / italic / link) appear when the user
 * has entered an in-place text session on this block AND has a non-empty
 * text selection inside it. The controller (`InplaceTextController`)
 * registers itself with the service as `wireframeInplaceText.controller`; we
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
  @service wireframeBlockMutations;
  @service wireframeDragSession;
  @service wireframeEntryConfig;
  @service wireframeForceExpand;
  @service wireframeInplaceText;
  @service wireframeLayoutQuery;
  @service wireframeLayoutSignal;
  @service wireframeSelection;

  /**
   * Working value of the URL input while a field-editor slot is
   * active. Seeded from `wireframeInplaceText.fieldEditor.value` when the input
   * mounts (see `seedFieldEditorValue`). The slot's `value` is the
   * INITIAL value; this is the live edit-in-progress string the user
   * is typing.
   */
  @tracked editorValue = "";

  /**
   * The last fit tier `computeFit` decided, mirrored into tracked state. `d-fit`
   * applies the tier as a DOM attribute, which Glimmer's tracking can't see; the
   * roving-focus cursor reads this (through `rovingKey`) so it re-seeds when a
   * fold hides the button currently holding the single tab stop. Never read from
   * the template directly, so it takes the `_` fallback.
   */
  @tracked _fitTier = FIT_TIERS.full;

  get canMoveUp() {
    return this.wireframeSelection.canMoveSelectedUp;
  }

  get canMoveDown() {
    return this.wireframeSelection.canMoveSelectedDown;
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
    const _v = this.wireframeLayoutSignal.version;
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(
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
   * The active in-place text controller, or `null` when no inline
   * session is open.
   */
  get inlineController() {
    return this.wireframeInplaceText.controller;
  }

  /**
   * Whether the inline-format buttons should be visible. Requires:
   *   - an active in-place text session on THIS block,
   *   - a non-empty PM selection that the schema marks can apply to.
   *
   * @returns {boolean}
   */
  get showInlineFormat() {
    return (
      !!this.inlineController &&
      this.wireframeInplaceText.blockKey === this.args.blockKey &&
      this.inlineController.markState !== null
    );
  }

  get markState() {
    return this.inlineController?.markState;
  }

  /**
   * `true` when the toolbar should render its URL-edit surface for
   * the rich text link mark — i.e. PM has entered link-mark
   * mode (`enterLinkMode` in `inplace-text-controller.gjs`), which
   * populates `wireframeInplaceText.fieldEditor` with `kind === "url"`.
   *
   * Block-arg URL edits (e.g. a button's `href`) are no longer routed
   * through here — those open an anchored `InplaceLinkPopover` next to
   * the link element instead. The rich-text link mark has no DOM
   * anchor of its own, so it stays on the toolbar.
   */
  get isUrlFieldEditing() {
    return this.wireframeInplaceText.fieldEditor?.kind === "url";
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
   * The key that re-seeds the roving-focus cursor. It must change whenever the
   * set of usable toolbar buttons changes, so the single tab stop never strands
   * on a button that was removed or hidden:
   *   - `isSelected` toggles the whole action set on and off,
   *   - `isUrlFieldEditing` and `showInlineFormat` swap in entirely different
   *     button groups,
   *   - the fit tier folds the action row into the hamburger (the off-tier group
   *     is `visibility:hidden`, which `dRovingFocus` now treats as unusable),
   *   - the action descriptors themselves change which buttons render and which
   *     are disabled (skipped as tab targets).
   *
   * @returns {string}
   */
  get rovingKey() {
    const actions = this.actionItems
      .map((item) => `${item.id}:${item.disabled ? 1 : 0}`)
      .join(",");
    return [
      this.args.isSelected ? "s" : "",
      this._fitTier,
      this.isUrlFieldEditing ? "u" : "",
      this.showInlineFormat ? "f" : "",
      actions,
    ].join("|");
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
    const _v = this.wireframeLayoutSignal.version;
    return this.wireframeLayoutQuery.isComposedComposite(this.args.blockKey);
  }

  /**
   * The single, ordered source of truth for the bar's collapsible (structural)
   * actions. Both the inline action row and the hamburger menu render from this
   * list, so they can never drift. Each descriptor is one of:
   *
   *   - a plain icon button: `{ id, group, icon, title, action, disabled?,
   *     active?, danger? }`.
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

    // Every block except the outlet root can step up to its parent (the
    // enclosing container, or the outlet when it sits at the top).
    if (!this.args.isOutletRoot) {
      items.push({
        id: "select-parent",
        group: "nav",
        icon: "arrow-turn-up",
        title: "wireframe.canvas.toolbar.select_parent",
        action: this.selectParent,
      });
    }

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
      items.push({
        id: "duplicate",
        group: "primary",
        icon: "copy",
        title: "wireframe.canvas.toolbar.duplicate",
        action: this.duplicate,
      });
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
   * The bar's fit decision, run in the fit coordinator's shared read phase
   * (reads only — nothing is written). Reads the natural widths of the bar's
   * parts from the toolbar element: the leading group (handle + any
   * always-inline format buttons) and BOTH the collapsible action row and the
   * hamburger are always in the DOM — the off-tier one sits absolutely
   * positioned at `max-content`, so every `offsetWidth` reports its true
   * intrinsic width regardless of the current tier. No styles are toggled to
   * measure. The width-to-tier mapping itself lives in the pure `computeTier`.
   *
   * @param {number} avail - The chrome's available content width.
   * @param {HTMLElement} toolbarEl - The bar root (the element `d-fit` is on).
   * @returns {"full"|"narrow"|"narrower"}
   */
  @action
  computeFit(avail, toolbarEl) {
    const widthOf = (selector) =>
      toolbarEl.querySelector(selector)?.offsetWidth ?? 0;

    const leading =
      widthOf(".wireframe-block-toolbar__handle") +
      widthOf(".wireframe-block-toolbar__format");

    const tier = computeTier(
      avail,
      leading + widthOf(".wireframe-block-toolbar__actions"),
      leading + widthOf(".wireframe-block-toolbar__more")
    );
    // Mirror the decided tier into tracked state for `rovingKey`. This runs in
    // the fit coordinator's post-render read phase, so the assignment schedules
    // a normal re-render rather than tripping a backtracking assertion, and it
    // can't loop: the tier isn't one of `d-fit`'s remeasure inputs.
    this._fitTier = tier;
    return tier;
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
  selectParent() {
    this.wireframeSelection.selectParent();
  }

  @action
  duplicate() {
    this.wireframeBlockMutations.duplicateBlock(this.args.blockKey);
  }

  @action
  remove() {
    this.wireframeBlockMutations.removeBlock(this.args.blockKey);
  }

  @action
  detach() {
    this.wireframeEntryConfig.detachSelectedComposite();
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
    this.wireframeInplaceText.fieldEditor?.apply?.(this.editorValue);
  }

  @action
  removeFieldEditor() {
    this.wireframeInplaceText.fieldEditor?.remove?.();
  }

  @action
  cancelFieldEditor() {
    this.wireframeInplaceText.fieldEditor?.cancel?.();
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
    this.editorValue = this.wireframeInplaceText.fieldEditor?.value ?? "";
    element.focus();
    element.select();
  }

  @action
  startDrag({ source }) {
    this.wireframeDragSession.startDrag(source.data);
  }

  <template>
    <div
      class="wireframe-block-toolbar"
      role="toolbar"
      aria-label={{i18n "wireframe.canvas.toolbar_label" name=@displayName}}
      {{! An idle toolbar sits at opacity:0 but stays in the a11y tree, so every
        unselected block would otherwise leak a phantom named toolbar to
        assistive tech. Hide those. The outlet root stays exposed: its always-on
        status chip is information its region should announce. }}
      aria-hidden={{unless (or @isSelected @isOutletRoot) "true"}}
      {{dFit
        this.computeFit
        observedEl=@chromeEl
        attribute="data-wf-toolbar-fit"
        active=this.fitActive
        remeasureOn=(array
          this.actionItems
          @displayName
          @displayChip
          this.isUrlFieldEditing
          this.showInlineFormat
        )
      }}
      {{dRovingFocus
        orientation="horizontal"
        itemSelector=".wireframe-block-toolbar__btn"
        itemsKey=this.rovingKey
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
            onDrop=this.wireframeDragSession.endDrag
          }}
        >
          {{dIcon "grip-vertical"}}
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
          {{#if this.wireframeInplaceText.fieldEditor.remove}}
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
            {{/each}}
          </div>

          {{! Overflow menu — the collapsed home for the actions above. Only
              movable blocks collapse, so outlet roots and parts render no
              overflow menu (their few actions stay inline). The menu renders the
              same actions list as text items. }}
          {{#if this.isCollapsible}}
            <DMenu
              class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__more"
              @identifier="wireframe-toolbar-more"
              @icon="ellipsis-vertical"
              @placement="bottom-start"
              @title="wireframe.canvas.toolbar.more"
              @ariaLabel="wireframe.canvas.toolbar.more"
            >
              <:content as |args|>
                <DDropdownMenu as |dropdown|>
                  {{#each this.actionItems as |item|}}
                    {{! A divider reproduces the inline grouping (primary /
                        image / danger) as menu separators. }}
                    {{#if item.separatorBefore}}
                      <dropdown.divider />
                    {{/if}}
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
