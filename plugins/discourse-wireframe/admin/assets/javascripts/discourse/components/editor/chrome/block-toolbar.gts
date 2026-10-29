import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import DMenuUntyped from "discourse/float-kit/components/d-menu";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import type BlocksService from "discourse/services/blocks";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource, {
  type DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import {
  blockRenderStatuses,
  type BlockStatus,
} from "discourse/plugins/discourse-wireframe/discourse/lib/block-status";
import {
  entryKey,
  findEntrySiblings,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import type WireframeBlockMutationsService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-mutations";
import WireframeDragSessionService, {
  type BlockDragPayload,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drag-session";
import type WireframeEntryConfigService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-entry-config";
import type WireframeForceExpandService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-force-expand";
import WireframeInplaceTextService, {
  type InplaceTextController,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-inplace-text";
import WireframeLayoutQueryService, {
  OUTLET_STATE,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeRailService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";
import WireframeSelectionService, {
  type BlockAncestrySegment,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

/**
 * One entry in the strip's actions menu. Rendered as a menu item; `group`
 * transitions insert the dividers.
 */
type ToolbarActionItem = {
  /** Stable action identifier. */
  id: string;
  /** Visual group used to insert separators. */
  group: string;
  /** Icon rendered for the action. */
  icon: string;
  /** Translated action title. */
  title: string;
  /** Callback invoked by the action. */
  action?: () => void;
  /** Whether the action is unavailable. */
  disabled?: boolean;
  /** Whether the action represents active state. */
  active?: boolean;
  /** Whether the action uses destructive styling. */
  danger?: boolean;
  /** Whether a divider precedes the action; set from `group` transitions. */
  separatorBefore?: boolean;
};

interface BlockToolbarSignature {
  /** Arguments controlling strip identity, state, and optional actions. */
  Args: {
    /** Composite key of the represented block. */
    blockKey: string;
    /** Outlet containing the represented block. */
    outletName?: string;
    /** Human-readable block name. */
    displayName?: string;
    /** Full tooltip title for the represented block. */
    displayTitle?: string;
    /** Optional compact identity chip. */
    displayChip?: string | number;
    /** Visual axis used for sibling movement. */
    moveAxis?: "horizontal" | "vertical";
    /** Whether the represented block is an outlet root. */
    isOutletRoot?: boolean;
    /** Whether the block sits inside another block, not directly in the outlet. */
    isNested?: boolean;
    /** Whether the represented block is a container. */
    isContainer?: boolean;
    /** Number of direct children the block renders. */
    childCount?: number;
    /** Current outlet publication state. */
    outletState?: string;
    /** Whether the represented outlet has staged edits. */
    isOutletEditing?: boolean;
    /** Chrome element the drag preview is copied from. */
    chromeEl?: HTMLElement;
    /** Whether the represented block is selected. */
    isSelected?: boolean;
    /** Whether the wrapped block is a ghost (failed / unknown entry). */
    isGhost?: boolean;
    /** Whether the ghost is a genuine authoring error. */
    isError?: boolean;
    /** Category of render failure for a ghost. */
    failureType?: string;
    /** The block's render conditions tree. */
    conditions?: object | object[] | null;
    /** Layout warnings the chrome detected for the strip's status. */
    warnings?: BlockStatus[];
    /** Whether the represented image can be reset. */
    canResetImage?: boolean;
    /** Resets the represented image. */
    onResetImage?: () => void;
    /** Opens quick actions for the block's image. */
    onEditImage?: () => void;
  };
  /** Root strip element. */
  Element: HTMLDivElement;
}

interface StripCrumbsSignature {
  /** The ancestry to render and the segment pick handler. */
  Args: {
    /** Ancestor segments, outlet first. */
    segments: BlockAncestrySegment[];
    /** Selects the picked ancestor. */
    onPick: (segment: BlockAncestrySegment) => void;
  };
}

/** How many ancestors the strip shows inline before folding the middle. */
const MAX_INLINE_ANCESTORS = 2;

// TODO(devxp-typescript-pending): drop once d-menu is authored in .gts with a
// real Signature, then import it directly. Untyped .gjs today gives no
// arg/block/attr types, so its Element (for `...attributes`) and the `content`
// block's yielded value are declared here.
const DMenu = DMenuUntyped as unknown as ComponentLike<{
  /** Arguments accepted by the menu trigger. */
  Args: {
    /** Stable menu identifier. */
    identifier?: string;
    /** Trigger icon. */
    icon?: string;
    /** FloatKit placement. */
    placement?: string;
    /** Trigger tooltip. */
    title?: string;
    /** Accessible trigger label. */
    ariaLabel?: string;
  };
  /** Root menu element. */
  Element: HTMLElement;
  /** Blocks yielded by the menu. */
  Blocks: {
    /** Menu content receiving a close callback. */
    content: [
      {
        /** Closes the menu. */
        close: () => void;
      },
    ];
  };
}>;

/**
 * The ancestors of a selected nested block, each a button that re-selects that
 * ancestor, separated by chevrons. Rendered inside the strip's handle in place
 * of the bare name. Deep nesting folds everything between the outlet and the
 * immediate parent into a "…" segment that opens a menu of those ancestors, so
 * the strip never crams more than two ancestors inline.
 */
class StripCrumbs extends Component<StripCrumbsSignature> {
  /** The ancestors shown inline: all of them, or the outlet and the parent. */
  get inline(): BlockAncestrySegment[] {
    const segments = this.args.segments;
    if (segments.length <= MAX_INLINE_ANCESTORS) {
      return segments;
    }
    return [segments[0]!, segments[segments.length - 1]!];
  }

  /** The ancestors folded into the "…" segment. */
  get folded(): BlockAncestrySegment[] {
    const segments = this.args.segments;
    return segments.length > MAX_INLINE_ANCESTORS ? segments.slice(1, -1) : [];
  }

  /** The outlet segment, rendered first. */
  get first(): BlockAncestrySegment | undefined {
    return this.inline[0];
  }

  /** The remaining inline segments after the outlet. */
  get rest(): BlockAncestrySegment[] {
    return this.inline.slice(1);
  }

  /**
   * Selects a folded ancestor, closing the menu first so the selection change
   * (which re-renders this strip) never fires against a torn-down portal.
   *
   * @param segment - The picked ancestry segment.
   * @param close - The menu's close callback.
   */
  @action
  pickFolded(segment: BlockAncestrySegment, close?: () => void): void {
    close?.();
    this.args.onPick(segment);
  }

  <template>
    {{#if this.first}}
      <DButton
        class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__crumb"
        @action={{fn @onPick this.first}}
        @translatedLabel={{this.first.displayName}}
      />
      {{dIcon "chevron-right" class="wireframe-block-toolbar__crumb-sep"}}
    {{/if}}
    {{#if this.folded.length}}
      <DMenu
        class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__crumb wireframe-block-toolbar__crumb--folded"
        @ariaLabel="wireframe.canvas.toolbar.folded_ancestors"
        @icon="ellipsis"
        @identifier="wireframe-strip-crumbs"
        @placement="bottom-start"
        @title="wireframe.canvas.toolbar.folded_ancestors"
      >
        <:content as |args|>
          <DDropdownMenu as |dropdown|>
            {{#each this.folded as |segment|}}
              <dropdown.item>
                <DButton
                  class="btn-flat wireframe-block-toolbar__menu-item"
                  @action={{fn this.pickFolded segment args.close}}
                  @translatedLabel={{segment.displayName}}
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
      {{dIcon "chevron-right" class="wireframe-block-toolbar__crumb-sep"}}
    {{/if}}
    {{#each this.rest as |segment|}}
      <DButton
        class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__crumb"
        @action={{fn @onPick segment}}
        @translatedLabel={{segment.displayName}}
      />
      {{dIcon "chevron-right" class="wireframe-block-toolbar__crumb-sep"}}
    {{/each}}
  </template>
}

/**
 * The header strip attached to the top edge of every outlet and block chrome.
 * Rendered in flow as the chrome's first child, it carries:
 *
 *   1. Handle region — the grip (drag source) and the block's name, or, for
 *      a selected nested block, a breadcrumb of its ancestors ending in the
 *      name. The outlet root shows the outlet icon and name instead and
 *      carries no drag source; a composite part reads as a part.
 *   2. Trailing region — the outlet's publish state, or the block's render
 *      status (hidden by conditions, failed to render, a viewport or
 *      persona condition, a layout warning), or a container's child count;
 *      the in-place text format buttons and the link URL editor while an
 *      inline edit is open; then the actions: a gear that opens the inspector
 *      and a "…" menu holding the structural actions (select parent,
 *      duplicate, move, detach, expand, image actions, remove).
 *
 * The strip is always visible so the block stays labelled; CSS reveals the
 * actions on hover (innermost chrome only) or selection, and keeps the
 * outlet's menu visible at all times.
 *
 * Inline-format buttons use `@preventFocus={{true}}` on `DButton` so the
 * mousedown's default focus shift is suppressed — ProseMirror keeps focus and
 * the selection highlight stays visible while the mark applies. They never
 * fold into the menu: a menu item click can't preserve the ProseMirror
 * selection the way `@preventFocus` does.
 */
export default class BlockToolbar extends Component<BlockToolbarSignature> {
  /** Resolves outlet display names for the breadcrumb. */
  @service declare blocks: BlocksService;

  /** Applies structural mutations for menu actions. */
  @service declare wireframeBlockMutations: WireframeBlockMutationsService;

  /** Owns the active block drag payload. */
  @service declare wireframeDragSession: WireframeDragSessionService;

  /** Applies selected-entry configuration changes. */
  @service declare wireframeEntryConfig: WireframeEntryConfigService;

  /** Owns per-block edit-presentation overrides. */
  @service declare wireframeForceExpand: WireframeForceExpandService;

  /** Coordinates the active in-place text editor. */
  @service declare wireframeInplaceText: WireframeInplaceTextService;

  /** Reads metadata and layout placement for the represented block. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Exposes the shared layout invalidation signal. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Opens the inspector for the gear action. */
  @service declare wireframeRail: WireframeRailService;

  /** Owns selection state and the selected block's ancestry. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * Working value of the URL input while a field-editor slot is
   * active. Seeded from `wireframeInplaceText.fieldEditor.value` when the input
   * mounts (see `seedFieldEditorValue`). The slot's `value` is the
   * INITIAL value; this is the live edit-in-progress string the user
   * is typing.
   */
  @tracked editorValue = "";

  /** Whether the block has an earlier sibling to move before. */
  get canMoveUp(): boolean {
    const position = this.#siblingPosition;
    return !!position && position.index > 0;
  }

  /** Whether the block has a later sibling to move after. */
  get canMoveDown(): boolean {
    const position = this.#siblingPosition;
    return !!position && position.index < position.count - 1;
  }

  /**
   * Whether the block's siblings run horizontally (a tabs / carousel parent, or
   * a `layout` in row mode), so the reorder actions read left/right rather than
   * up/down. The underlying move is the same "earlier / later sibling" in both
   * orientations — only the icons and labels change.
   */
  get isHorizontalMove(): boolean {
    return this.args.moveAxis === "horizontal";
  }

  /** Icon for moving to the earlier sibling. */
  get moveBackIcon(): string {
    return this.isHorizontalMove ? "arrow-left" : "arrow-up";
  }

  /** Icon for moving to the later sibling. */
  get moveForwardIcon(): string {
    return this.isHorizontalMove ? "arrow-right" : "arrow-down";
  }

  /** i18n key for the earlier-sibling move. */
  get moveBackLabel(): string {
    return this.isHorizontalMove
      ? "wireframe.canvas.toolbar.move_left"
      : "wireframe.canvas.toolbar.move_up";
  }

  /** i18n key for the later-sibling move. */
  get moveForwardLabel(): string {
    return this.isHorizontalMove
      ? "wireframe.canvas.toolbar.move_right"
      : "wireframe.canvas.toolbar.move_down";
  }

  /**
   * `true` when the menu should expose the "expand for editing"
   * toggle. Shown for `wf:layout` blocks whose `autoCollapse` isn't
   * `"never"` — i.e. the layout could actually collapse at narrow
   * widths, so an override has something to override.
   */
  get canForceExpand(): boolean {
    void this.wireframeLayoutSignal.version;
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
   */
  get isForceExpanded(): boolean {
    return this.wireframeForceExpand.isForceExpanded(this.args.blockKey);
  }

  /**
   * The active in-place text controller, or `null` when no inline
   * session is open.
   */
  get inlineController(): InplaceTextController | null {
    return this.wireframeInplaceText.controller;
  }

  /**
   * Whether the inline-format buttons should be visible. Requires:
   *   - an active in-place text session on THIS block,
   *   - a non-empty PM selection that the schema marks can apply to.
   */
  get showInlineFormat(): boolean {
    return (
      !!this.inlineController &&
      this.wireframeInplaceText.blockKey === this.args.blockKey &&
      this.inlineController.markState !== null
    );
  }

  /** Active inline mark state exposed by the in-place text controller. */
  get markState(): InplaceTextController["markState"] | undefined {
    return this.inlineController?.markState;
  }

  /**
   * `true` when the strip should render its URL-edit surface for
   * the rich text link mark — i.e. PM has entered link-mark
   * mode (`enterLinkMode` in `inplace-text-controller.gts`), which
   * populates `wireframeInplaceText.fieldEditor` with `kind === "url"`.
   *
   * Block-arg URL edits (e.g. a button's `href`) are no longer routed
   * through here — those open an anchored `InplaceLinkPopover` next to
   * the link element instead. The rich-text link mark has no DOM
   * anchor of its own, so it stays on the strip.
   */
  get isUrlFieldEditing(): boolean {
    return this.wireframeInplaceText.fieldEditor?.kind === "url";
  }

  /**
   * `true` when this strip belongs to a synthesized composite part (which
   * has no persisted entry). Structural actions — move, duplicate, delete,
   * drag-to-reorder — are meaningless for a part, so the strip hides them.
   */
  get isPart(): boolean {
    return isPartKey(this.args.blockKey);
  }

  /**
   * `true` for an ordinary movable block — neither the outlet root (a page
   * region) nor a composite part. Only movable blocks carry the structural
   * actions.
   */
  get isMovable(): boolean {
    return !this.args.isOutletRoot && !this.isPart;
  }

  /**
   * Whether the menu offers "Select parent". Hidden when the parent is the
   * outlet itself — stepping up to a page region isn't a meaningful move — but
   * kept for a composite part, whose parent is the composite it belongs to.
   */
  get showSelectParent(): boolean {
    if (this.args.isOutletRoot) {
      return false;
    }
    if (this.isPart) {
      return true;
    }
    return !this.parentIsOutletRoot;
  }

  /** Whether the block sits directly in the outlet's implicit root layout. */
  get parentIsOutletRoot(): boolean {
    void this.wireframeLayoutSignal.version;
    const parent = this.wireframeLayoutQuery.findEntryParent(
      this.args.blockKey
    );
    if (!parent) {
      return true;
    }
    const parentKey = entryKey(parent);
    return (
      parentKey == null || this.wireframeLayoutQuery.isOutletRoot(parentKey)
    );
  }

  /**
   * The ancestors shown as a breadcrumb in place of the bare name: only for the
   * selected nested block, from the outlet down to (not including) the block.
   * The outlet's implicit root layout IS the outlet, so it collapses into the
   * outlet segment, which reads by the outlet's display name.
   */
  get ancestors(): BlockAncestrySegment[] {
    if (!this.args.isSelected || !this.args.isNested) {
      return [];
    }
    if (this.wireframeSelection.selectedBlockKey !== this.args.blockKey) {
      return [];
    }
    return this.wireframeSelection.selectedBlockAncestry
      .slice(0, -1)
      .filter(
        (segment) =>
          segment.key == null ||
          !this.wireframeLayoutQuery.isOutletRoot(segment.key)
      )
      .map((segment) =>
        segment.isOutlet
          ? {
              ...segment,
              displayName:
                this.blocks.getOutletMetadata(segment.outletName)
                  ?.displayName ?? segment.displayName,
            }
          : segment
      );
  }

  /** Whether the handle shows the ancestry breadcrumb. */
  get showBreadcrumb(): boolean {
    return this.ancestors.length > 0;
  }

  /** The block's render statuses, most important first. */
  @cached
  get statuses(): BlockStatus[] {
    return blockRenderStatuses({
      isGhost: this.args.isGhost,
      isError: this.args.isError,
      failureType: this.args.failureType,
      conditions: this.args.conditions,
      warnings: this.args.warnings,
    });
  }

  /** The status the strip shows; the rest go into its title. */
  get primaryStatus(): BlockStatus | null {
    return this.statuses[0] ?? null;
  }

  /** Every status, for the strip's tooltip. */
  get statusTitle(): string | undefined {
    const parts = this.statuses.map((status) => status.title ?? status.label);
    return parts.length > 0 ? parts.join(" · ") : undefined;
  }

  /** A container's child count, shown when it has no status to report. */
  get childCountLabel(): string | null {
    const count = this.args.childCount ?? 0;
    if (!this.args.isContainer || count === 0) {
      return null;
    }
    return i18n("wireframe.canvas.strip.block_count", { count });
  }

  /**
   * The outlet's publish state as the strip names it: unsaved edits supersede
   * the persisted state; an outlet nothing has published yet is a draft.
   */
  get publishState(): string {
    if (this.args.isOutletEditing) {
      return "unpublished_changes";
    }
    switch (this.args.outletState) {
      case OUTLET_STATE.PUBLISHED:
        return "published";
      case OUTLET_STATE.LOCKED:
        return "locked";
      default:
        return "draft";
    }
  }

  /** Translated publish state label. */
  get publishStateLabel(): string {
    return i18n(`wireframe.outlet.state.${this.publishState}`);
  }

  /**
   * The key that re-seeds the roving-focus cursor. It must change whenever the
   * set of usable strip buttons changes, so the single tab stop never strands
   * on a button that was removed or hidden: selection toggles the actions,
   * the URL editor and inline format swap in different button groups, the
   * breadcrumb adds buttons, and the action descriptors change which menu
   * trigger renders.
   */
  get rovingKey(): string {
    const actions = this.actionItems
      .map((item) => `${item.id}:${item.disabled ? 1 : 0}`)
      .join(",");
    return [
      this.args.isSelected ? "s" : "",
      this.isUrlFieldEditing ? "u" : "",
      this.showInlineFormat ? "f" : "",
      this.showBreadcrumb ? "b" : "",
      actions,
    ].join("|");
  }

  /**
   * `true` when this block is a composed composite (renders a code-defined
   * `parts` composition) and can therefore be detached into explicit,
   * freely-editable children.
   */
  get canDetach(): boolean {
    void this.wireframeLayoutSignal.version;
    return this.wireframeLayoutQuery.isComposedComposite(this.args.blockKey);
  }

  /**
   * The single, ordered source of truth for the strip's menu. Each descriptor
   * is `{ id, group, icon, title, action, disabled?, active?, danger? }`;
   * `separatorBefore` is computed from `group` transitions so the menu shows
   * a divider between groups. Outlet roots and parts omit the structural
   * actions (move/duplicate/detach/delete), leaving only whatever applies (e.g.
   * the force-expand toggle on a layout).
   */
  @cached
  get actionItems(): ToolbarActionItem[] {
    const items: ToolbarActionItem[] = [];

    if (this.showSelectParent) {
      items.push({
        id: "select-parent",
        group: "nav",
        icon: "arrow-turn-up",
        title: "wireframe.canvas.toolbar.select_parent",
        action: this.selectParent,
      });
    }

    if (this.isMovable) {
      items.push({
        id: "duplicate",
        group: "primary",
        icon: "copy",
        title: "wireframe.canvas.toolbar.duplicate",
        action: this.duplicate,
      });
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
        group: "layout",
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

    if (this.args.onEditImage) {
      items.push({
        id: "image-edit",
        group: "image",
        icon: "image",
        title: "wireframe.canvas.toolbar.image_edit",
        action: this.args.onEditImage,
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

    if (this.isMovable) {
      items.push({
        id: "delete",
        group: "danger",
        icon: "trash-can",
        title: "wireframe.canvas.toolbar.delete",
        danger: true,
        action: this.remove,
      });
    }

    // A divider marks each group boundary.
    let prevGroup = null;
    for (const item of items) {
      item.separatorBefore = prevGroup !== null && item.group !== prevGroup;
      prevGroup = item.group;
    }

    return items;
  }

  /** The block's index among its siblings, read from the live layout. */
  get #siblingPosition(): {
    /** Zero-based index among the siblings. */
    index: number;
    /** Number of siblings, the block included. */
    count: number;
  } | null {
    void this.wireframeLayoutSignal.version;
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    );
    if (!located) {
      return null;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return null;
    }
    const found = findEntrySiblings(layout, this.args.blockKey);
    return found ? { index: found.index, count: found.siblings.length } : null;
  }

  /** Toggles edit-presentation expansion for the represented block. */
  @action
  toggleForceExpand(): void {
    this.wireframeForceExpand.toggleForceExpand(this.args.blockKey);
  }

  /** Moves the represented block toward its earlier sibling. */
  @action
  moveUp(): void {
    this.wireframeBlockMutations.moveBlockUp(this.args.blockKey);
  }

  /** Moves the represented block toward its later sibling. */
  @action
  moveDown(): void {
    this.wireframeBlockMutations.moveBlockDown(this.args.blockKey);
  }

  /** Selects the represented block's parent. */
  @action
  selectParent(): void {
    this.wireframeSelection.selectParent();
  }

  /** Duplicates the represented block. */
  @action
  duplicate(): void {
    this.wireframeBlockMutations.duplicateBlock(this.args.blockKey);
  }

  /** Removes the represented block. */
  @action
  remove(): void {
    this.wireframeBlockMutations.removeBlock(this.args.blockKey);
  }

  /** Detaches a composed block into freely editable child entries. */
  @action
  detach(): void {
    this.wireframeEntryConfig.detachSelectedComposite();
  }

  /**
   * Opens the inspector on its settings. The click also bubbles to the chrome,
   * which selects the block if it wasn't already.
   */
  @action
  openSettings(): void {
    this.wireframeRail.showInspector();
  }

  /**
   * Selects an ancestor picked in the breadcrumb. The outlet segment selects
   * the outlet's implicit root layout, the same target as "Select parent"
   * reaches from a top-level block.
   *
   * @param segment - The picked ancestry segment.
   */
  @action
  pickAncestor(segment: BlockAncestrySegment): void {
    if (segment.isOutlet) {
      const rootKey = this.wireframeLayoutQuery.outletRootKey(
        segment.outletName
      );
      if (rootKey) {
        this.wireframeSelection.selectBlock({ key: rootKey, name: "layout" });
      }
      return;
    }
    if (segment.key && segment.blockName) {
      this.wireframeSelection.selectBlock({
        key: segment.key,
        name: segment.blockName,
      });
    }
  }

  /**
   * Runs a menu action once the menu has closed, so the action never fires
   * against a torn-down portal (remove unmounts this strip) and an action that
   * opens its own popover (the image quick actions) doesn't race the close.
   *
   * @param actionFn - The descriptor's action.
   * @param close - The menu's close callback.
   */
  @action
  async invokeFromMenu(
    actionFn?: () => void,
    close?: () => void | Promise<void>
  ): Promise<void> {
    await close?.();
    actionFn?.();
  }

  /** Toggles bold on the active in-place selection. */
  @action
  toggleBold(): void {
    this.inlineController?.toggleMark("strong");
  }

  /** Toggles italic on the active in-place selection. */
  @action
  toggleItalic(): void {
    this.inlineController?.toggleMark("em");
  }

  /** Opens the inline link field editor. */
  @action
  startLinkEdit(): void {
    this.inlineController?.enterLinkMode();
  }

  /** Applies the active inline field editor value. */
  @action
  applyFieldEditor(): void {
    this.wireframeInplaceText.fieldEditor?.apply?.(this.editorValue);
  }

  /** Removes the value managed by the active inline field editor. */
  @action
  removeFieldEditor(): void {
    this.wireframeInplaceText.fieldEditor?.remove?.();
  }

  /** Cancels the active inline field editor. */
  @action
  cancelFieldEditor(): void {
    this.wireframeInplaceText.fieldEditor?.cancel?.();
  }

  /**
   * Updates the working URL value.
   *
   * @param event - URL input event.
   */
  @action
  onUrlInput(
    event: Event & {
      /** URL input that emitted the event. */
      currentTarget: Element;
    }
  ): void {
    if (event.currentTarget instanceof HTMLInputElement) {
      this.editorValue = event.currentTarget.value;
    }
  }

  /**
   * Applies or cancels the URL editor from the keyboard.
   *
   * @param event - Keyboard event from the URL input.
   */
  @action
  onUrlKeydown(event: KeyboardEvent): void {
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
   *
   * @param element - Mounted URL input element.
   */
  @action
  seedFieldEditorValue(element: HTMLInputElement): void {
    this.editorValue = this.wireframeInplaceText.fieldEditor?.value ?? "";
    element.focus();
    element.select();
  }

  /**
   * Starts an existing-block drag session.
   *
   * @param event - Drag-start event supplied by the source modifier.
   */
  @action
  startDrag({ source }: { source: DragSource }): void {
    this.wireframeDragSession.startDrag(
      source.data as unknown as BlockDragPayload
    );
  }

  /**
   * Renders the native drag image: a copy of the whole chrome in its selected
   * dress (see `.--drag-preview`), sized like the original so the preview
   * reads as the block being lifted off the page.
   *
   * @param target - The offscreen container the browser photographs.
   * @returns A cleanup that removes the copy once the drag image is captured.
   */
  @action
  renderDragPreview({
    container,
  }: {
    /** The offscreen container to render into. */
    container: HTMLElement;
  }): () => void {
    const source = this.args.chromeEl;
    if (!source) {
      return () => {};
    }
    const copy = source.cloneNode(true) as HTMLElement;
    copy.classList.remove("--drag-source");
    copy.classList.add("--drag-preview", "--selected");
    copy.style.width = `${source.offsetWidth}px`;
    container.appendChild(copy);
    return () => copy.remove();
  }

  <template>
    <div
      {{! An idle strip stays in the a11y tree, so every unselected block would
        otherwise leak a phantom named toolbar to assistive tech. Hide those.
        The outlet root stays exposed: its always-on publish state is
        information its region should announce. }}
      aria-hidden={{unless (or @isSelected @isOutletRoot) "true"}}
      aria-label={{i18n "wireframe.canvas.toolbar_label" name=@displayName}}
      class={{dConcatClass
        "wireframe-block-toolbar"
        (if @isOutletRoot "--outlet")
        (if @isNested "--nested")
        (if this.primaryStatus (concat "--status-" this.primaryStatus.tone))
      }}
      role={{unless this.isUrlFieldEditing "toolbar"}}
      {{dRovingFocus
        orientation="horizontal"
        itemSelector=".wireframe-block-toolbar__btn"
        itemsKey=this.rovingKey
      }}
    >
      <div class="wireframe-block-toolbar__bar">
        {{! Handle region — always present so block identity stays visible,
          and so the drag-source modifier's registration is stable across
          hover transitions. The outlet root is a page region, not a movable
          block: its handle carries no drag source. }}
        {{#if @isOutletRoot}}
          <span
            class="wireframe-block-toolbar__handle wireframe-block-toolbar__handle--outlet"
            title={{@displayName}}
          >
            {{dIcon "cubes" class="wireframe-block-toolbar__grip"}}
            <span class="wireframe-block-toolbar__name">{{@displayName}}</span>
          </span>
        {{else if this.isPart}}
          {{! A composite part isn't a movable block — its handle reads as a
            part (dashed icon + name) and carries no drag source. }}
          <span
            class="wireframe-block-toolbar__handle wireframe-block-toolbar__handle--part"
            title={{@displayName}}
          >
            {{dIcon "circle-dashed" class="wireframe-block-toolbar__grip"}}
            {{#if this.showBreadcrumb}}
              <StripCrumbs
                @onPick={{this.pickAncestor}}
                @segments={{this.ancestors}}
              />
            {{/if}}
            <span class="wireframe-block-toolbar__name">{{@displayName}}</span>
          </span>
        {{else}}
          {{! The handle title carries the block name so the identity stays
            discoverable when a narrow strip truncates the name. }}
          <span
            class="wireframe-block-toolbar__handle"
            title={{@displayName}}
            {{dDragAndDropSource
              type="wf-block"
              data=(hash blockKey=@blockKey outletName=@outletName)
              dragPreview=this.renderDragPreview
              dragPreviewOffset=(hash x="16px" y="12px")
              onDragStart=this.startDrag
              onDragEnd=this.wireframeDragSession.endDrag
            }}
          >
            {{dIcon "grip-vertical" class="wireframe-block-toolbar__grip"}}
            {{#if this.showBreadcrumb}}
              <StripCrumbs
                @onPick={{this.pickAncestor}}
                @segments={{this.ancestors}}
              />
            {{/if}}
            {{! The displayTitle arg carries a fuller name (e.g. a tab's own
              label) for a block shown by ordinal; absent for ordinary blocks.
              The displayChip arg, when present, is the block's position within
              an ordinal-naming container (a tabs panel, a carousel slide),
              shown as a chip beside the name. }}
            <span
              class="wireframe-block-toolbar__name"
              title={{@displayTitle}}
            >{{@displayName}}</span>
            {{#if @displayChip}}
              <span
                class="wireframe-block-toolbar__ordinal"
              >{{@displayChip}}</span>
            {{/if}}
          </span>
        {{/if}}

        <span class="wireframe-block-toolbar__trail">
          {{#if @isOutletRoot}}
            <span
              class={{dConcatClass
                "wireframe-block-toolbar__status"
                "wireframe-block-toolbar__status--publish"
                (concat "--" this.publishState)
              }}
              title={{this.publishStateLabel}}
            >
              <span
                aria-hidden="true"
                class="wireframe-block-toolbar__dot"
              ></span>
              <span
                class="wireframe-block-toolbar__status-text"
              >{{this.publishStateLabel}}</span>
            </span>
          {{else if this.primaryStatus}}
            <span
              class={{dConcatClass
                "wireframe-block-toolbar__status"
                (concat "--" this.primaryStatus.tone)
              }}
              data-wf-status={{this.primaryStatus.id}}
              title={{this.statusTitle}}
            >
              {{dIcon this.primaryStatus.icon}}
              <span
                class="wireframe-block-toolbar__status-text"
              >{{this.primaryStatus.label}}</span>
            </span>
          {{else if this.childCountLabel}}
            <span
              class="wireframe-block-toolbar__count"
            >{{this.childCountLabel}}</span>
          {{/if}}

          {{#if @isSelected}}
            {{#if this.isUrlFieldEditing}}
              <input
                class="wireframe-block-toolbar__url-input"
                placeholder="https://..."
                type="url"
                value={{this.editorValue}}
                {{didInsert this.seedFieldEditorValue}}
                {{on "input" this.onUrlInput}}
                {{on "keydown" this.onUrlKeydown}}
              />
              <DButton
                class="btn-flat wireframe-block-toolbar__btn"
                @action={{this.applyFieldEditor}}
                @ariaLabel="wireframe.canvas.toolbar.link_apply"
                @icon="check"
                @preventFocus={{true}}
                @title="wireframe.canvas.toolbar.link_apply"
              />
              {{#if this.wireframeInplaceText.fieldEditor.remove}}
                <DButton
                  class="btn-flat wireframe-block-toolbar__btn"
                  @action={{this.removeFieldEditor}}
                  @ariaLabel="wireframe.canvas.toolbar.link_remove"
                  @icon="link-slash"
                  @preventFocus={{true}}
                  @title="wireframe.canvas.toolbar.link_remove"
                />
              {{/if}}
              <DButton
                class="btn-flat wireframe-block-toolbar__btn"
                @action={{this.cancelFieldEditor}}
                @ariaLabel="wireframe.canvas.toolbar.link_cancel"
                @icon="xmark"
                @preventFocus={{true}}
                @title="wireframe.canvas.toolbar.link_cancel"
              />
            {{else if this.showInlineFormat}}
              {{! The preventFocus arg keeps PM focused while a mark applies. }}
              <span class="wireframe-block-toolbar__format">
                <DButton
                  class={{if
                    this.markState.strong
                    "btn-flat wireframe-block-toolbar__btn --active"
                    "btn-flat wireframe-block-toolbar__btn"
                  }}
                  @action={{this.toggleBold}}
                  @ariaLabel="wireframe.canvas.toolbar.bold"
                  @ariaPressed={{this.markState.strong}}
                  @icon="bold"
                  @preventFocus={{true}}
                  @title="wireframe.canvas.toolbar.bold"
                />
                <DButton
                  class={{if
                    this.markState.em
                    "btn-flat wireframe-block-toolbar__btn --active"
                    "btn-flat wireframe-block-toolbar__btn"
                  }}
                  @action={{this.toggleItalic}}
                  @ariaLabel="wireframe.canvas.toolbar.italic"
                  @ariaPressed={{this.markState.em}}
                  @icon="italic"
                  @preventFocus={{true}}
                  @title="wireframe.canvas.toolbar.italic"
                />
                <DButton
                  class={{if
                    this.markState.link
                    "btn-flat wireframe-block-toolbar__btn --active"
                    "btn-flat wireframe-block-toolbar__btn"
                  }}
                  @action={{this.startLinkEdit}}
                  @ariaLabel="wireframe.canvas.toolbar.link"
                  @ariaPressed={{this.markState.link}}
                  @icon="link"
                  @preventFocus={{true}}
                  @title="wireframe.canvas.toolbar.link"
                />
              </span>
            {{/if}}
          {{/if}}

          {{#unless this.isUrlFieldEditing}}
            {{! The gear + "…" pair. CSS reveals them on hover / selection; the
              outlet keeps its menu visible. }}
            <span class="wireframe-block-toolbar__actions">
              {{#unless @isOutletRoot}}
                <DButton
                  class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__settings"
                  data-toolbar-action="settings"
                  @action={{this.openSettings}}
                  @ariaLabel="wireframe.canvas.toolbar.settings"
                  @icon="gear"
                  @title="wireframe.canvas.toolbar.settings"
                />
              {{/unless}}
              {{#if this.actionItems.length}}
                <DMenu
                  class="btn-flat wireframe-block-toolbar__btn wireframe-block-toolbar__more"
                  @ariaLabel="wireframe.canvas.toolbar.more"
                  @icon="ellipsis"
                  @identifier="wireframe-toolbar-more"
                  @placement="bottom-end"
                  @title="wireframe.canvas.toolbar.more"
                >
                  <:content as |args|>
                    <DDropdownMenu as |dropdown|>
                      {{#each this.actionItems as |item|}}
                        {{#if item.separatorBefore}}
                          <dropdown.divider />
                        {{/if}}
                        <dropdown.item>
                          <DButton
                            class={{dConcatClass
                              "btn-flat"
                              "wireframe-block-toolbar__menu-item"
                              (if item.active "--active")
                              (if
                                item.danger
                                "wireframe-block-toolbar__menu-item--danger"
                              )
                            }}
                            data-toolbar-action={{item.id}}
                            @action={{fn
                              this.invokeFromMenu
                              item.action
                              args.close
                            }}
                            @disabled={{item.disabled}}
                            @icon={{item.icon}}
                            @title={{item.title}}
                            @translatedLabel={{i18n item.title}}
                          />
                        </dropdown.item>
                      {{/each}}
                    </DDropdownMenu>
                  </:content>
                </DMenu>
              {{/if}}
            </span>
          {{/unless}}
        </span>
      </div>
    </div>
  </template>
}
