import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { assert } from "@ember/debug";
import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { type default as Owner, getOwner } from "@ember/owner";
import { cancel, next, schedule, type Timer } from "@ember/runloop";
import { service } from "@ember/service";
import type { ComponentLike, ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import DHeadlessMenu from "discourse/float-kit/components/d-headless-menu";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import discourseLater from "discourse/lib/later";
import type A11yService from "discourse/services/a11y";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
  registerDragAndDropTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * How long after the last chord move the full announcement lands. Long enough
 * that a held key reads as one run rather than a stream of sentences, short
 * enough that a deliberate single press still speaks it as a single press.
 */
const RUN_SETTLE_MS = 400;

/** The list's move menu, identified by the attribute float-kit stamps on it. */
const MENU_IDENTIFIER = "reorderable-list-move";
const MENU_CONTENT_SELECTOR = `[data-identifier="${MENU_IDENTIFIER}"]`;

/** The destination each accelerator chord asks for. */
const CHORD_TARGETS: Record<string, MoveTarget | undefined> = {
  ArrowUp: "up",
  ArrowDown: "down",
  Home: "top",
  End: "bottom",
};

/**
 * One normalized move, as both input methods report it. The indices and item
 * arrays all describe the VISIBLE list — the `items` the consumer passed —
 * never a backing store the consumer may keep behind it.
 */
export interface ReorderableMove<T = unknown> {
  /** How the user asked for the move. */
  method: "drag" | "menu" | "keyboard";

  /** The item that moved, resolved against the current items at commit time. */
  item: T;

  /** The list the item left. Always `"default"` for a standalone list. */
  fromList: string;

  /** The list the item entered. Always `"default"` for a standalone list. */
  toList: string;

  /** The item's visible index before the move. */
  fromIndex: number;

  /** The item's visible index after the move. */
  toIndex: number;

  /** The visible items before the move, exactly as passed in `@items`. */
  fromItems: readonly T[];

  /** The visible items before the move; the same array for a single list. */
  toItems: readonly T[];

  /** The proposed visible order after the move. */
  proposedFromItems: readonly T[];

  /** The proposed visible order; the same array for a single list. */
  proposedToItems: readonly T[];
}

/**
 * The row's own position and its pre-wired controls, yielded to `<:row>`
 * beside the item. Conventionally bound as `controls`, matching the
 * `@controls` argument that decides whether the list places them or the
 * consumer does.
 */
export interface ReorderableRowApi {
  /** The row's index in the visible list. */
  index: number;

  /** Whether the row occupies the first movable slot. */
  isFirst: boolean;

  /** Whether the row occupies the last movable slot. */
  isLast: boolean;

  /** Whether the row can be reordered at all. */
  movable: boolean;

  /**
   * The pre-wired handle for this row, present only under
   * `@controls="manual"` on a movable row. It is the drag source and the move
   * menu's trigger at once, so a movable manual row must place it; a
   * development assertion fires when one does not.
   */
  handle?: ComponentLike<{ Element: HTMLElement }>;

  /**
   * The pre-wired remove control, present only under `@controls="manual"` on a
   * removable row when `@onRemove` is set. Carries its own accessible name;
   * everything visual passes through.
   */
  remove?: ComponentLike<{ Element: HTMLElement }>;
}

/** The context handed to a `@rowClass` function. */
interface RowClassContext {
  index: number;
  movable: boolean;
}

/**
 * What a member list registers with its group: identity, the optional
 * translated list name for cross-list announcements, and closures reading the
 * member's live state — closures rather than snapshots, so a drop resolves
 * against the source list as it stands at drop time.
 */
export interface ReorderableGroupMember {
  listId: string;
  listLabel?: string;

  /** The member's current visible items. */
  getItems: () => readonly unknown[];

  /**
   * The source half of a cross-list move: resolves the dragged key against
   * the member's current rows and returns the item, its visible index, and
   * the member's proposed order without it — or `undefined` when the key no
   * longer resolves to a movable row.
   */
  removalProjection: (key: string) =>
    | {
        item: unknown;
        fromIndex: number;
        proposedFromItems: readonly unknown[];
      }
    | undefined;

  /**
   * The destination half of a cross-list move, as the menu path calls it. A
   * drop already runs on the destination, but a menu item runs on the source,
   * so the source reaches across to the member that owns the projections and
   * the announcement for where the item is landing.
   *
   * @param sourceListId - The member the item is leaving.
   * @param key - The moved row's key in that member.
   * @param toIndex - The visible landing index in this member.
   */
  acceptMove: (sourceListId: string, key: string, toIndex: number) => void;
}

/**
 * The API a `DReorderableListGroup` yields to its block. Member lists receive
 * it as `@group`; everything on it is wiring between the group and its
 * members rather than a consumer surface.
 */
export interface ReorderableGroupApi {
  /**
   * The shared drag discriminator. Members adopt it in place of their own, so
   * drags travel freely inside the group and nowhere else.
   */
  token: string;

  /** Adds a member; returns its deregistration. Duplicate listIds assert. */
  registerMember: (member: ReorderableGroupMember) => () => void;

  /** The member registered under a listId, if it still exists. */
  lookupMember: (listId: string) => ReorderableGroupMember | undefined;

  /**
   * The other members registered right now, in registration order, as the
   * move menu's cross-list destinations. Only members carrying a `listLabel`
   * are returned: an unnamed destination has nothing to put in the menu item,
   * so it stays pointer-only rather than offering "Move to undefined".
   */
  siblings: (listId: string) => { listId: string; listLabel: string }[];

  /** The group's single move callback, shared by every member. */
  onMove: (move: ReorderableMove) => void | false;
}

/**
 * The internal per-row view model the component renders from. Rows are
 * recomputed from `@items` on every relevant change, so anything an event
 * handler needs later is re-resolved by `key` rather than captured.
 */
interface Row<T> {
  item: T;
  key: string;
  index: number;
  movable: boolean;
  isFirst: boolean;
  isLast: boolean;
  disableUp: boolean;
  disableDown: boolean;
  /** The row's own accessible name: what the reader is moving. */
  label: string;
  handleLabel: string;

  /** Shared by the row's `aria-describedby` and its handle's description. */
  descriptionId: string;

  /** Whether this row may be removed at all. */
  removable: boolean;

  /** The remove control's accessible name. */
  removeLabel: string;
  yieldControls: boolean;
}

interface DReorderableListSignature<T> {
  Args: {
    /**
     * The visible items in display order. The component reasons, indexes, and
     * announces only in this list; projecting a reorder onto hidden backing
     * storage stays with the consumer. Never mutated by the component.
     */
    items: readonly T[];

    /**
     * Property path resolving each item's stable identity, used for keyed
     * rendering and for resolving drag payloads at drop time. The literal
     * value `"@index"` opts into index-based identity for primitive
     * collections whose values may repeat. Omitted, object identity is used,
     * which is only safe when the same objects are passed on every render.
     *
     * Index identity is positional by definition: after a move, rows keep
     * their positions while items flow through them, so focus and drag state
     * stay with a position rather than following the moved item. That is how
     * position-addressed value lists already behave, and is the trade-off
     * accepted when items carry no identity of their own.
     */
    key?: string;

    /**
     * Translated display name for an item. It names the drag handle, both
     * arrow buttons, and the post-move announcement, so every control stays
     * distinguishable when read out of context.
     */
    label: (item: T) => string;

    /**
     * The single move callback. Pointer drops and arrow presses both arrive
     * here, already normalized and no-op-suppressed. Return `false` to veto
     * the announcement; the consumer then owns whatever feedback replaces it.
     * Required for a standalone list; a grouped member omits it — the group's
     * own callback receives every member move instead.
     */
    onMove?: (move: ReorderableMove<T>) => void | false;

    /**
     * The API yielded by a surrounding `DReorderableListGroup`. Joining a
     * group makes cross-list moves between members possible and routes every
     * move through the group's callback. Requires `@listId`. Fixed at
     * construction: a list that must change groups is re-created, not
     * re-pointed. Every member carrying a `@listLabel` also becomes a
     * destination in the other members' move menus, which is how a cross-list
     * move is reachable without a pointer.
     */
    group?: ReorderableGroupApi;

    /**
     * This member's identity inside its group. Required with `@group`, and
     * fixed at construction like the group itself.
     */
    listId?: string;

    /**
     * Translated name for this list, spoken in cross-list announcements when
     * an item lands here from another member, and shown as this list's
     * "Move to …" entry in every other member's move menu. Without it the
     * standard announcement is used and the list stays a pointer-only
     * destination.
     */
    listLabel?: string;

    /**
     * Rows failing this predicate are frozen: they render no controls, are
     * not drag sources, refuse drops, and keep their exact visible index in
     * every proposed order. Arrow moves hop over them. Defaults to every row
     * being movable.
     */
    movable?: (item: T) => boolean;

    /** Tag name for the list element. Defaults to `"ul"`. */
    tag?: string;

    /** Tag name for each row element. Defaults to `"li"`. */
    itemTag?: string;

    /** Optional ARIA role for the list element. */
    role?: string;

    /**
     * Optional ARIA role for each row element. Use roles that permit
     * interactive descendants (such as `row`): a role whose children are
     * presentational (`option`, `menuitem`, `tab`) flattens the rendered
     * controls out of the accessibility tree.
     */
    itemRole?: string;

    /**
     * Extra class(es) for the row element: a static string, or a function of
     * the item and its `{ index, movable }` state.
     */
    rowClass?: string | ((item: T, context: RowClassContext) => string);

    /**
     * Who places the row's handle. `"auto"` (the default) renders it ahead of
     * the row's block content; `"manual"` renders none and instead yields a
     * pre-wired `handle` component on the row API, for layouts where it must
     * occupy a specific cell, grid track, or position.
     *
     * There is deliberately no automatic "at the end": a handle is focusable,
     * so where it sits in the DOM is its position in the reading and focus
     * order, not decoration. A row that wants it last says so by placing it
     * last.
     */
    controls?: "auto" | "manual";

    /**
     * Read-only mode: rows render without controls and without any drag
     * wiring, as if every row were frozen.
     */
    disabled?: boolean;

    /**
     * Overrides the announcement for a committed move. Return the text to
     * announce, or `false` to suppress the announcement entirely. `onMove`
     * has already run either way.
     */
    announceMove?: (move: ReorderableMove<T>) => string | false;

    /**
     * Renders a create affordance after the rows: a text input and an add
     * button by default, or the `<:create>` block when one is given. The
     * default row is list-shaped (it renders as one extra item element), so a
     * table shell should supply its own `<:create>` block with valid cell
     * markup.
     */
    allowCreate?: boolean;

    /**
     * Reports that the reader asked to remove an item. Supplying it is what
     * renders the remove control: trailing the row's own content by default,
     * or wherever `controls.remove` is placed under `@controls="manual"`.
     *
     * The visible index comes with it, because an index-keyed list may hold
     * the same value twice and the item alone would not say which row went.
     *
     * The list announces the removal and puts focus somewhere sensible
     * afterwards; the handler's only job is to drop the item from its store.
     */
    onRemove?: (item: T, index: number) => void;

    /**
     * Whether an item may be removed, defaulting to all of them.
     *
     * Mirrors `@movable`, which renders no handle on a row that cannot move:
     * a row that cannot be removed renders no remove control either. A
     * permanently protected row would otherwise carry a dead tab stop that
     * announces itself as unavailable on every pass. This is deliberately
     * unlike the menu's boundary destinations, which stay marked because
     * reaching an end is temporary and the row will move again.
     */
    removable?: (item: T) => boolean;

    /**
     * The remove control's icon. One list-level argument rather than a
     * per-row one, because the control is placed by the list in every mode
     * except manual.
     */
    removeIcon?: string;

    /**
     * Called with the trimmed value when the default create affordance is
     * submitted. Never called for an empty or whitespace-only value.
     */
    onCreate?: (value: string) => void;
  };
  Blocks: {
    /**
     * The contents of one row, rendered inside the row element the component
     * owns. Named rather than the implicit block because what it fills is not
     * obvious: a table shell yields `td`s into a `tr` the consumer never
     * writes, and `<:default>` gave no way to tell that from replacing the
     * row outright.
     */
    row: [item: T, row: ReorderableRowApi];

    /** Rendered inside the list element, before every row. */
    header: [];

    /**
     * Rendered before the header, for the visible sentence that teaches the
     * interaction ("Drag the handle, or press Enter for move options"). The
     * component never renders one of its own: a dense table wants no such
     * paragraph, and where it belongs on the page is the surface's call. The
     * screen-reader description on each handle is separate and always
     * present.
     */
    hint: [];

    /** Rendered in the rows' position when `@items` is empty. */
    empty: [];

    /**
     * Replaces the default create affordance when `@allowCreate` is set,
     * rendered after the rows.
     */
    create: [];
  };
  Element: HTMLElement;
}

/** Where a menu-driven move sends the row. */
type MoveTarget = "up" | "down" | "top" | "bottom";

interface MoveItemSignature {
  Args: {
    target: string;
    icon: string;
    label: string;
    disabled?: boolean;
    move: () => void;
  };
}

/**
 * One destination in the move menu.
 *
 * Unavailable directions are marked rather than removed, and marked with
 * `aria-disabled` rather than the `disabled` attribute, so the menu presents
 * the same destinations on every row and a reader who lands on one at a
 * boundary is told it is unavailable instead of finding it missing. The guard
 * lives in the handler for the same reason.
 *
 * Each destination carries its own modifier class, which is what lets a test
 * or a page object name the destination it wants rather than counting menu
 * positions that shift as soon as a group adds a cross-list entry.
 */
const MoveItem: TOC<MoveItemSignature> = <template>
  <DButton
    @icon={{@icon}}
    @translatedLabel={{@label}}
    @action={{@move}}
    aria-disabled={{if @disabled "true"}}
    class={{dConcatClass
      "btn-transparent d-reorderable-list__move-item"
      (concat "--" @target)
    }}
  />
</template>;

interface HandlePartSignature {
  Args: {
    row: Row<unknown>;

    /** Opens the list's shared menu against this row. */
    onOpen: (key: string) => void;

    /** Whether the shared menu is currently open on this row. */
    isOpen: boolean;
    register: ModifierLike<{ Args: { Positional: [string] } }>;
  };
  Element: HTMLElement;
}

/** What the shared move menu is told to act on. */
interface MoveMenuData {
  /** The list that owns the menu, asked for live row state as it renders. */
  list: {
    rowFor: (key: string) => Row<unknown> | undefined;
    siblings: () => { listId: string; listLabel: string }[];
    onMenuMove: (key: string, target: MoveTarget) => void;
    onMenuMoveToList: (key: string, listId: string, close: () => void) => void;
  };

  /** The row the menu was opened from. */
  key: string;
}

interface MoveMenuSignature {
  Args: {
    data?: MoveMenuData;
    close?: () => void;
  };
}

/**
 * The destinations behind one handle.
 *
 * Rendered by the list's single menu instance rather than per row, so it reads
 * the row it was opened for out of `@data` and asks the list for that row's
 * live state. Boundary marks therefore reflect the list as it stands while the
 * menu is open, not as it stood when the row last rendered.
 *
 * A disclosure of ordinary buttons rather than `role="menu"`, which keeps the
 * reader in the same browse mode they navigate the rest of the page with. No
 * float-kit float is a menu: the role lands on the float's outer wrapper, two
 * levels above the list of buttons, where it could never own menu items.
 */
class MoveMenu extends Component<MoveMenuSignature> {
  get row(): Row<unknown> | undefined {
    return this.args.data?.list.rowFor(this.args.data.key);
  }

  get siblings(): { listId: string; listLabel: string }[] {
    return this.args.data?.list.siblings() ?? [];
  }

  @action
  move(target: MoveTarget) {
    const { data } = this.args;
    data?.list.onMenuMove(data.key, target);
  }

  @action
  moveToList(listId: string) {
    const { data, close } = this.args;
    data?.list.onMenuMoveToList(data.key, listId, close ?? (() => {}));
  }

  <template>
    <DDropdownMenu as |dropdown|>
      <dropdown.item>
        <MoveItem
          @target="top"
          @icon="angles-up"
          @label={{i18n "reorder.move_to_top"}}
          @disabled={{this.row.disableUp}}
          @move={{fn this.move "top"}}
        />
      </dropdown.item>
      <dropdown.item>
        <MoveItem
          @target="up"
          @icon="arrow-up"
          @label={{i18n "reorder.move_up"}}
          @disabled={{this.row.disableUp}}
          @move={{fn this.move "up"}}
        />
      </dropdown.item>
      <dropdown.item>
        <MoveItem
          @target="down"
          @icon="arrow-down"
          @label={{i18n "reorder.move_down"}}
          @disabled={{this.row.disableDown}}
          @move={{fn this.move "down"}}
        />
      </dropdown.item>
      <dropdown.item>
        <MoveItem
          @target="bottom"
          @icon="angles-down"
          @label={{i18n "reorder.move_to_bottom"}}
          @disabled={{this.row.disableDown}}
          @move={{fn this.move "bottom"}}
        />
      </dropdown.item>
      {{#if this.siblings.length}}
        <dropdown.divider />
        {{#each this.siblings key="listId" as |sibling|}}
          <dropdown.item>
            <MoveItem
              @target="list"
              {{! Deliberately not a directional arrow: the list has no idea
                where a sibling sits on the page, so an arrow would point the
                wrong way as often as not. }}
              @icon="right-left"
              @label={{i18n "reorder.move_to_list" list=sibling.listLabel}}
              @move={{fn this.moveToList sibling.listId}}
            />
          </dropdown.item>
        {{/each}}
      {{/if}}
    </DDropdownMenu>
  </template>
}

/**
 * The one control a movable row renders: a real button that is the drag
 * source and the move menu's trigger at once.
 *
 * Fusing the two is what lets the row carry a single affordance. A pointer
 * user drags it or clicks it for the menu; a keyboard user tabs or arrows onto
 * it and presses Enter for the same menu, because nothing intercepts a plain
 * button's native activation.
 *
 * The menu itself belongs to the list, not to this button: a list is arbitrarily
 * long, and one instance and one set of listeners per row is a cost that scales
 * with the wrong thing. The button therefore carries the menu's ARIA itself,
 * driven by the list's single record of which row is open.
 *
 * The drag registration belongs to the row for the same reason it is not here:
 * the registered element is what a drop target receives and what the browser
 * photographs for the drag preview. Registered on this button, a drag would
 * show a picture of the grip rather than of the row being moved. The row
 * registers instead and names this button as its `dragHandle`.
 */
class HandlePart extends Component<HandlePartSignature> {
  @action
  open() {
    this.args.onOpen(this.args.row.key);
  }

  <template>
    <DButton
      {{@register @row.key}}
      @icon="grip-vertical"
      @action={{this.open}}
      @translatedAriaLabel={{@row.handleLabel}}
      @translatedTitle={{@row.handleLabel}}
      @ariaExpanded={{@isOpen}}
      aria-describedby={{@row.descriptionId}}
      class="btn-flat d-reorderable-list__handle"
      ...attributes
    >
      <span id={{@row.descriptionId}} class="sr-only">
        {{i18n "reorder.handle_description"}}
      </span>
    </DButton>
  </template>
}

interface RemovePartSignature {
  Args: {
    row: Row<unknown>;

    /** The icon to render, from the list's `@removeIcon`. */
    icon: string;

    /** Reports the row the reader asked to remove. */
    onRemove: (key: string) => void;
  };
  Element: HTMLElement;
}

/**
 * The standard remove control for one row.
 *
 * Only its contract is fixed: an accessible name built from the row's own
 * label, and the disabled state the list computed. Everything visual is the
 * consumer's — `@icon` and any attribute pass straight through — because a
 * settings row and an admin table want different weights for the same action.
 *
 * The name is the part worth centralising. Every surface that hand-rolled this
 * rendered an icon-only button with no name at all, so a ten-row list offered a
 * reader ten identical "button"s and no way to tell what each one removed.
 */
const RemovePart: TOC<RemovePartSignature> = <template>
  <DButton
    @icon={{@icon}}
    @action={{fn @onRemove @row.key}}
    @translatedAriaLabel={{@row.removeLabel}}
    @translatedTitle={{@row.removeLabel}}
    class="btn-flat d-reorderable-list__remove"
    ...attributes
  />
</template>;

interface CreateRowSignature {
  Args: {
    itemTag: string;
    onCreate?: (value: string) => void;
  };
}

/**
 * The default create affordance: a text input and an add button rendered as
 * one extra row. Submitting via Enter or the button reports the trimmed value
 * and clears the input; an empty or whitespace-only value reports nothing.
 */
class CreateRow extends Component<CreateRowSignature> {
  captureInput = modifier((element: HTMLInputElement) => {
    this.#input = element;
    return () => (this.#input = undefined);
  });
  /**
   * The live input element. Read directly at submit time instead of mirroring
   * keystrokes into tracked state: the value only matters at that moment, and
   * clearing must reach the element's property — resetting a bound attribute
   * would not clear what the user typed.
   */
  #input?: HTMLInputElement;

  @action
  onKeydown(event: KeyboardEvent) {
    // A keydown arriving mid-IME-composition belongs to the candidate window,
    // not to this control.
    if (event.key === "Enter" && !event.isComposing) {
      event.preventDefault();
      this.#submit();
    }
  }

  @action
  submit() {
    this.#submit();
  }

  #submit() {
    const element = this.#input;
    const value = element?.value.trim();
    // Without a handler the value has nowhere to go, so it stays in the input
    // instead of being silently discarded.
    if (!element || !value || !this.args.onCreate) {
      return;
    }
    this.args.onCreate(value);
    element.value = "";
  }

  <template>
    {{#let (dElement @itemTag) as |Wrapper|}}
      <Wrapper class="d-reorderable-list__create">
        <input
          {{this.captureInput}}
          {{on "keydown" this.onKeydown}}
          type="text"
          class="d-reorderable-list__create-input"
          aria-label={{i18n "reorder.add_item"}}
        />
        <DButton
          @icon="plus"
          @action={{this.submit}}
          @translatedAriaLabel={{i18n "reorder.add_item"}}
          @translatedTitle={{i18n "reorder.add_item"}}
          class="btn-flat d-reorderable-list__create-button"
        />
      </Wrapper>
    {{/let}}
  </template>
}

/**
 * A reorderable list: the standard shell for any surface where the user
 * changes the order of visible rows.
 *
 * The component owns the whole interaction — keyed iteration, the drag
 * handle, the move menu, the keyboard path, boundary state, drop
 * normalization, no-op suppression, focus restoration, and the screen-reader
 * announcement — so a consumer supplies only its row content and one
 * `@onMove` that projects the proposed visible order into its own store.
 * Every input method converges on a single commit: one callback and one
 * announcement per real move, and neither for a move that lands where it
 * started.
 *
 * The handle inside each row is the pointer affordance: the drag source and
 * the move menu's trigger at once. It is also an ordinary tab stop. The list
 * is not a composite widget, since its rows are content carrying their own
 * controls rather than alternatives to choose between, so nothing here manages
 * the tab sequence and every focusable thing in a row is reached in document
 * order.
 *
 * - **Pointer**: drag the handle, or click it and choose a destination. The
 *   menu is the single-pointer path WCAG 2.5.1 and 2.5.7 require, since a
 *   drag alone leaves anyone who cannot perform one with nothing.
 * - **Keyboard**: Tab reaches every handle and every control a row renders.
 *   Enter or Space on a handle opens its move menu through ordinary button
 *   activation, and Escape closes it. There is no mode to enter or leave.
 * - **Accelerators**: on a focused handle, a bare arrow moves focus to the
 *   neighbouring handle, stepping over the rows' own controls. Alt with an
 *   arrow moves the row one step, and Alt with Home/End sends it to an end.
 *   Every accelerator is refused anywhere but a handle, so a row's own field
 *   keeps its arrows and its chords, and none of them is ever the only path:
 *   assistive software that swallows one costs speed rather than access.
 *
 * A move at either end is refused and the refusal is announced, and the
 * destination stays in the menu marked unavailable rather than disappearing:
 * reaching an end is something the reader should be told, and the silent
 * boundary no-op is one of the failures this component exists to stop
 * surfaces from reinventing.
 *
 * The list and row elements stay stylable and semantically flexible through
 * `@tag` / `@itemTag` / `@role` / `@itemRole`, which is what lets one
 * component serve plain lists and ARIA table shapes alike.
 *
 * @example
 * ```gjs
 * <DReorderableList
 *   @items={{this.sections}}
 *   @key="id"
 *   @label={{this.sectionLabel}}
 *   @onMove={{this.applyMove}}
 *   class="my-sections"
 * >
 *   <:row as |section|>
 *     <span>{{section.name}}</span>
 *   </:row>
 * </DReorderableList>
 * ```
 */
export default class DReorderableList<T> extends Component<
  DReorderableListSignature<T>
> {
  @service declare a11y: A11yService;

  /**
   * The list's one menu, created on first use and re-anchored per row. Tracked
   * because the template renders it, and it does not exist until a row asks.
   */
  @tracked menu: DMenuInstance | null = null;
  /**
   * The row whose menu is open, and the list's only record of it. One menu
   * means one answer: with an instance per row there were as many claims about
   * what was open as there were rows, and keeping them agreeing was work the
   * design should not have needed.
   */
  @tracked openKey: string | null = null;
  rowClassFor = (row: Row<T>): string | undefined => {
    const { rowClass } = this.args;
    if (typeof rowClass === "function") {
      return rowClass(row.item, { index: row.index, movable: row.movable });
    }
    return rowClass;
  };
  /**
   * Applied by the handle wherever it renders, so the component knows the row
   * kept its one control regardless of where a manual placement put it.
   */
  registerHandle = modifier((element: Element, [key]: [string]) => {
    this.#handles.set(key, element as HTMLElement);
    return () => {
      if (this.#handles.get(key) === element) {
        this.#handles.delete(key);
      }
    };
  });
  /**
   * Guards the manual-placement contract: a movable row under
   * `@controls="manual"` must place the yielded handle. It is the drag source,
   * the keyboard path and the single-pointer path at once, so a row that omits
   * it has no way to reorder at all. Checked once per row element, after its
   * first render — a consumer that conditionally removes its placed handle
   * later is beyond this guard's reach.
   */
  verifyKeyboardPath = modifier((element: Element) => {
    // The key is read from the element rather than taken as an argument: an
    // argument's tracking tag invalidates on every rows recompute, and a
    // function modifier that consumed it would tear down and re-run each
    // time. Reading only the element keeps this a strict once-per-element
    // lifecycle hook.
    if (!this.isManual) {
      return;
    }
    const key = element.getAttribute("data-reorderable-key") ?? "";
    schedule("afterRender", () => {
      if (isDestroying(this) || isDestroyed(this)) {
        return;
      }
      assert(
        `d-reorderable-list: the manual row "${key}" renders no handle — place the yielded handle, which is its only drag, keyboard and single-pointer path`,
        this.#handles.has(key)
      );
    });
  });
  /**
   * Clears the in-flight drag key when the dragged row is destroyed: a source
   * torn down mid-drag may never report its `dragend`, and the stale key
   * would otherwise mark a later row for the same item as still dragging.
   * Deferred a tick because the teardown runs inside a render pass that has
   * already read the key.
   */
  /**
   * Registers the list's root element as a drop target while the list is an
   * empty group member — the one state with no rows to land on. Applied
   * statically and registered imperatively: a conditionally curried modifier
   * breaks on the classic-component element wrapper the shell falls back to
   * for non-shortcut tags. Deliberately consumes `acceptsRootDrops`, so it
   * re-registers exactly when the items or group change — never mid-drag.
   */
  rootDropTarget = modifier((element: Element) => {
    if (!this.acceptsRootDrops) {
      return;
    }
    return registerDragAndDropTarget(element, () => ({
      accepts: this.dragType,
      position: "inside" as const,
      onDrop: this.onEmptyRootDrop,
    }));
  });

  /**
   * The keyboard accelerators, plus the focus bookkeeping the menu needs.
   *
   * Every branch is refused unless the press landed on a handle, so a row's
   * own field keeps the arrows and the Alt chords a caret needs. Neither
   * accelerator is ever the only path — the menu behind Enter is what a reader
   * whose software swallows one uses instead. Consumes nothing reactive: the
   * row is resolved at event time.
   */
  moveKeys = modifier((element: Element) => {
    this.#listElement = element;

    const onKeydown = (event: Event) => {
      const { key, altKey, target } = event as KeyboardEvent;
      if (
        !(target instanceof Element) ||
        !target.matches(".d-reorderable-list__handle")
      ) {
        return;
      }
      // A plain arrow walks between handles. An accelerator over Tab and never
      // the only path, so software that swallows it costs speed, not access.
      if (!altKey) {
        const step = key === "ArrowDown" ? 1 : key === "ArrowUp" ? -1 : 0;
        if (!step) {
          return;
        }
        const handles = Array.from(
          element.querySelectorAll<HTMLElement>(".d-reorderable-list__handle")
        );
        const next = handles[handles.indexOf(target as HTMLElement) + step];
        if (next) {
          event.preventDefault();
          next.focus();
        }
        return;
      }
      // An Alt chord pressed in a row's own control belongs to that control,
      // and Alt+Arrow is a live shortcut in a text field on several platforms.
      const destination = CHORD_TARGETS[key];
      if (!destination) {
        return;
      }
      const rowKey = target
        .closest("[data-reorderable-key]")
        ?.getAttribute("data-reorderable-key");
      if (!rowKey) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      this.#move(rowKey, destination, "keyboard");
    };

    const onFocusIn = (event: Event) => {
      if (!(event.target instanceof Element)) {
        return;
      }
      // The menu renders inside the list when it is not portaled, so its own
      // focus must not read as focus leaving the row it belongs to, which
      // would close the menu before a destination could be chosen.
      if (event.target.closest(MENU_CONTENT_SELECTOR)) {
        return;
      }
      // Any focus inside the row counts as being on the row, since its own
      // controls are part of it.
      const key = event.target
        .closest("[data-reorderable-key]")
        ?.getAttribute("data-reorderable-key");
      if (this.#focusedKey !== (key ?? null)) {
        this.#focusedKey = key ?? null;
        // The menu is anchored to one row, so focus that has moved on would
        // otherwise leave it floating over a row it no longer describes.
        if (this.openKey && this.openKey !== this.#focusedKey) {
          this.closeMenu(false);
        }
      }
    };

    const onFocusOut = () => {
      // Deferred past the render that may be moving the row: a move blurs its
      // handle until the after-render refocus lands, so only focus that has
      // settled outside the list clears the record.
      next(() => {
        if (
          isDestroying(this) ||
          isDestroyed(this) ||
          this.#listElement?.contains(document.activeElement) ||
          document.activeElement?.closest(MENU_CONTENT_SELECTOR)
        ) {
          return;
        }
        this.#focusedKey = null;
      });
    };

    const onRowClick = (event: Event) => {
      if (!(event.target instanceof Element)) {
        return;
      }
      // Interactive content owns its clicks, and the handle is already the
      // menu trigger, so only the row's dead space reaches the focus below.
      if (
        event.target.closest(
          "button, a, input, select, textarea, [tabindex], [contenteditable='true']"
        )
      ) {
        return;
      }
      // A drag-select of row text is not a request to move focus.
      const selection = window.getSelection();
      if (selection && !selection.isCollapsed) {
        return;
      }
      const row = event.target.closest("[data-reorderable-key]");
      if (!row || !element.contains(row)) {
        return;
      }
      row.querySelector<HTMLElement>(".d-reorderable-list__handle")?.focus();
    };

    element.addEventListener("keydown", onKeydown, { capture: true });
    element.addEventListener("click", onRowClick);
    element.addEventListener("focusin", onFocusIn);
    element.addEventListener("focusout", onFocusOut);
    return () => {
      element.removeEventListener("keydown", onKeydown, { capture: true });
      element.removeEventListener("click", onRowClick);
      element.removeEventListener("focusin", onFocusIn);
      element.removeEventListener("focusout", onFocusOut);
      this.#listElement = null;
    };
  });

  /**
   * A row's handle element, for the row's drag registration to point at.
   *
   * Deliberately untracked: modifiers install children-first, so a row's own
   * handle is in the map before the row's drag registration reads it. Making
   * it reactive only reintroduced the write-after-read this ordering avoids.
   *
   * @param key - The row key.
   */
  handleFor = (key: string): HTMLElement | undefined => this.#handles.get(key);
  /** The list's root element, held for post-move focus restoration. */
  #listElement: Element | null = null;
  /** The private drag discriminator used when the list stands alone. */
  #ownDragType = `d-reorderable-list:${guidFor(this)}`;

  /**
   * Each row's handle element, by key. Serves the manual-placement guard and
   * gives the shared menu something to anchor against when a row asks to open
   * it.
   */
  #handles = new Map<string, HTMLElement>();

  /**
   * The run of consecutive chord moves in flight, if any. A held Alt+arrow
   * would otherwise speak a full sentence per step into a live region that
   * re-announces even an unchanged string, so a run says only where the row
   * now is and the full sentence waits for the run to settle.
   */
  #run: { key: string; timer: Timer } | null = null;

  /**
   * The row focus is in, read only by the focus handler that decides whether
   * an open menu has been left behind.
   *
   * Deliberately untracked: the focus indicator is CSS on real DOM focus, so
   * nothing rendered consumes this. Tracking it means a `focusin` fired by the
   * after-render refocus writes a value the same computation has already read,
   * which is a backtracking-rerender assertion.
   */
  #focusedKey: string | null = null;

  constructor(owner: Owner, args: DReorderableListSignature<T>["Args"]) {
    super(owner, args);

    registerDestructor(this, () => {
      if (this.#run) {
        cancel(this.#run.timer);
        this.#run = null;
      }
    });

    const { group } = this.args;
    if (group && !this.args.listId) {
      // Reported after render rather than thrown here: an exception unwinding
      // a half-built render corrupts it. The list simply stays unregistered.
      schedule("afterRender", () => {
        if (isDestroying(this) || isDestroyed(this)) {
          return;
        }
        assert(
          "d-reorderable-list: @listId is required when the list joins a group",
          false
        );
      });
    } else if (group) {
      const unregister = group.registerMember({
        listId: this.args.listId!,
        listLabel: this.args.listLabel,
        getItems: () => this.args.items,
        acceptMove: (sourceListId: string, key: string, toIndex: number) => {
          this.#commitCrossMove(sourceListId, key, toIndex, "menu");
          // Focus follows the item across: the row is destroyed in the source
          // list's iteration and rebuilt in this one, so only the destination
          // can put focus back on it.
          this.#refocusRow(key);
        },
        removalProjection: (key: string) => {
          const rows = this.rows;
          const moved = rows.find((candidate) => candidate.key === key);
          if (!moved?.movable) {
            return undefined;
          }
          // The same slot model as an in-list move: frozen rows keep their
          // exact visible indices while the remaining movable items refill
          // the movable slots in order, and the list shrinks by its last
          // slot. A frozen row that sat on the dropped final slot has no
          // index to keep and joins the end of the refill queue.
          const size = rows.length - 1;
          const empty = Symbol("empty");
          const proposed: (T | typeof empty)[] = new Array(size).fill(empty);
          const overflow: T[] = [];
          for (const row of rows) {
            if (!row.movable) {
              if (row.index < size) {
                proposed[row.index] = row.item;
              } else {
                overflow.push(row.item);
              }
            }
          }
          const queue = rows
            .filter((row) => row.movable && row.key !== key)
            .map((row) => row.item)
            .concat(overflow);
          let cursor = 0;
          for (let index = 0; index < size; index++) {
            if (proposed[index] === empty) {
              proposed[index] = queue[cursor++]!;
            }
          }
          return {
            item: moved.item,
            fromIndex: moved.index,
            proposedFromItems: proposed as readonly T[],
          };
        },
      });
      registerDestructor(this, unregister);
    }
  }

  /**
   * The drag discriminator in force: the group's shared token when the list
   * is a member — which is what lets drags travel between members — and a
   * private per-instance one otherwise, so unrelated lists on one page can
   * never accept each other's drags.
   */
  get dragType(): string {
    return this.args.group?.token ?? this.#ownDragType;
  }

  get listTag(): string {
    return this.args.tag ?? "ul";
  }

  get itemTag(): string {
    return this.args.itemTag ?? "li";
  }

  /** The remove control's icon, defaulting to the list family's own. */
  get removeIcon(): string {
    return this.args.removeIcon ?? "xmark";
  }

  /** Whether the list places the remove control itself. */
  get rendersRemove(): boolean {
    return !!this.args.onRemove && !this.isManual;
  }

  /** Whether the remove control is the consumer's to place. */
  get rendersRemoveManually(): boolean {
    return !!this.args.onRemove && this.isManual;
  }

  get isManual(): boolean {
    return this.args.controls === "manual";
  }

  /**
   * The cross-list destinations this list's move menus offer: the group's
   * other named members. Empty for a standalone list, which is what makes the
   * menu collapse to its four in-list destinations without a conditional at
   * the call site.
   *
   * Handed to the handle as a function rather than an array, so the group is
   * consulted when a menu opens rather than while the row renders — members
   * are still registering at that point.
   */
  @action
  siblings(): { listId: string; listLabel: string }[] {
    return this.args.group?.siblings(this.listIdOrDefault) ?? [];
  }

  /** This list's move-payload identity: its group listId, or `"default"`. */
  get listIdOrDefault(): string {
    return this.args.listId ?? "default";
  }

  /**
   * Whether the list's root element accepts drops: only as an empty group
   * member, where there are no rows to land on. Reads `@items` directly
   * rather than `rows`, so the conditional target below re-curries only when
   * the items themselves change — never on drag-state churn.
   */
  get acceptsRootDrops(): boolean {
    return (
      !!this.args.group && this.args.items.length === 0 && !this.args.disabled
    );
  }

  /**
   * The per-row view models: identity, movability, boundary state, and the
   * translated control labels, computed in one pass so the template and the
   * event handlers read one consistent projection of `@items`.
   */
  get rows(): Row<T>[] {
    const { disabled, items, label, movable, removable } = this.args;
    const seen = new Set<string>();

    const rows = items.map((item, index) => {
      const key = this.#keyFor(item, index);
      assert(
        `d-reorderable-list: duplicate row key "${key}" — every item needs a unique key`,
        !seen.has(key)
      );
      seen.add(key);

      const itemLabel = label(item);
      const rowMovable = !disabled && (movable ? movable(item) : true);
      return {
        item,
        key,
        index,
        movable: rowMovable,
        isFirst: false,
        isLast: false,
        disableUp: false,
        disableDown: false,
        label: itemLabel,
        handleLabel: i18n("reorder.handle", { label: itemLabel }),
        // The description belongs to the row, but the element carrying the
        // text has to live inside the handle's button: a list element's
        // children are `li`, or the rows of whatever table shell a consumer
        // chose, and a bare `span` is legal in neither.
        descriptionId: `${guidFor(this)}-move-${index}`,
        removable: !disabled && (removable ? removable(item) : true),
        removeLabel: i18n("reorder.remove", { label: itemLabel }),
        yieldControls: rowMovable && this.isManual,
      };
    });

    const movableRows = rows.filter((row) => row.movable);
    // With a single movable item every direction is a no-op, so the whole
    // menu is marked unavailable rather than offering four destinations that
    // all lead nowhere.
    const alone = movableRows.length < 2;
    for (const [seqIndex, row] of movableRows.entries()) {
      row.isFirst = seqIndex === 0;
      row.isLast = seqIndex === movableRows.length - 1;
      row.disableUp = alone || row.isFirst;
      row.disableDown = alone || row.isLast;
    }

    return rows;
  }

  /**
   * Opens the list's one menu against a row's handle, creating it on first use.
   *
   * The instance is re-anchored rather than replaced, so a long list costs one
   * menu and one set of listeners no matter how many rows it has.
   *
   * @param key - The row whose handle was activated.
   */
  @action
  async openMenu(key: string) {
    const trigger = this.#handles.get(key);
    if (!trigger) {
      return;
    }

    if (this.openKey === key) {
      await this.closeMenu();
      return;
    }

    const instance = this.#menuInstance();
    // Listeners are off, so the trigger is only an anchor and reassigning it
    // is how one menu serves every row. The teardown is still required: the
    // base binds a pointer guard to whatever trigger it is given.
    instance.tearDownListeners();
    instance.trigger = trigger;
    instance.options = { ...instance.options, data: { list: this, key } };

    this.openKey = key;
    await instance.show();
    this.#focusFirstDestination();
  }

  /**
   * Puts focus on the first destination the reader can actually choose, or on
   * the first one of any kind when every destination is refused, so the menu
   * never opens with focus nowhere.
   */
  #focusFirstDestination() {
    const content = document.querySelector(MENU_CONTENT_SELECTOR);
    if (!content) {
      return;
    }
    const items = Array.from(
      content.querySelectorAll<HTMLElement>(".d-reorderable-list__move-item")
    );
    const target =
      items.find((item) => item.getAttribute("aria-disabled") !== "true") ??
      items[0];
    target?.focus();
  }

  /**
   * Closes the list's menu, if it is open.
   *
   * @param focusTrigger - Whether to hand focus back to the handle the menu
   *   was opened from. False when focus has already moved elsewhere: the
   *   menu's own habit of refocusing its trigger would otherwise drag focus
   *   back to the row the reader just left.
   */
  @action
  async closeMenu(focusTrigger = true) {
    this.openKey = null;
    if (this.menu?.expanded) {
      await this.menu.close({ focusTrigger });
    }
  }

  /**
   * The list's one menu, built on first open.
   *
   * Built rather than obtained from the `menu` service so that it keeps an
   * attached trigger: a service-created menu is rendered by the app-root
   * `DMenus`, which a component rendering in isolation has no access to. This
   * list renders its own, and `DFloatPortal` still teleports the content out
   * of the row's stacking context.
   */
  #menuInstance(): DMenuInstance {
    this.menu ??= new DMenuInstance(getOwner(this)!, {
      identifier: MENU_IDENTIFIER,
      placement: "bottom-start",
      component: MoveMenu,
      listeners: false,
      autoUpdate: true,
      // The panel holds a list of buttons and nothing else — no filter, no
      // controller of its own — so the float element steps out of the way
      // rather than announcing itself as a dialog wrapped around them.
      contentRole: "none",
      // Focus is placed by hand after opening, not by the tab trap: the trap
      // takes the first focusable, and a destination marked unavailable is
      // still focusable. A row at either boundary would open on a dead item,
      // and a list with one row has nothing but dead items above the
      // cross-list entries.
      autofocus: false,
      onClose: () => (this.openKey = null),
    });
    return this.menu;
  }

  /**
   * Removes a row on the reader's behalf: hand the item to the consumer, say
   * so, and leave focus somewhere it can act again.
   *
   * Focus is the part a consumer cannot reasonably get right on its own. The
   * control that was just pressed is gone with its row, so focus would fall to
   * the document without help, and a reader clearing several entries would be
   * thrown to the top of the page after each one.
   *
   * @param key - The row to remove.
   */
  @action
  onRemove(key: string) {
    const row = this.rows.find((candidate) => candidate.key === key);
    if (!row?.removable) {
      return;
    }
    const index = row.index;
    this.args.onRemove?.(row.item, index);
    this.a11y.announce(i18n("reorder.removed", { label: row.label }));
    schedule("afterRender", () => {
      if (isDestroying(this) || isDestroyed(this)) {
        return;
      }
      const controls = Array.from(
        this.#listElement?.querySelectorAll<HTMLElement>(
          ".d-reorderable-list__remove"
        ) ?? []
      );
      // The slot the removed row occupied, which now holds the row that
      // followed it; at the end of the list, the one before it instead.
      const next = controls[index] ?? controls.at(-1);
      next?.focus();
    });
  }

  /**
   * The row a key names, for the menu to read boundary state from while open.
   *
   * @param key - The row key.
   */
  rowFor(key: string): Row<T> | undefined {
    return this.rows.find((row) => row.key === key);
  }

  /**
   * A move chosen from the menu: commit, then close and hand focus back to the
   * handle, which the closing float would otherwise return to its pre-open
   * position.
   *
   * @param key - The row to move.
   * @param target - Where to move it.
   * @param close - Closes the menu the item was chosen from.
   */
  @action
  onMenuMove(key: string, target: MoveTarget) {
    // Closed without returning focus to the trigger: the move's own refocus
    // is what puts focus back, on the row that actually moved.
    this.closeMenu(false);
    this.#move(key, target, "menu");
  }

  /**
   * A cross-list move chosen from the menu, which is the only way to reach
   * another member without a pointer.
   *
   * @param key - The row to move.
   * @param listId - The destination member.
   * @param close - Closes the menu the item was chosen from.
   */
  @action
  onMenuMoveToList(key: string, listId: string, close: () => void) {
    close();
    const member = this.args.group?.lookupMember(listId);
    if (!member) {
      return;
    }
    // The destination lands the item, exactly as it does for a drop, because
    // the projections it needs are its own. This list only supplies the key.
    member.acceptMove(this.listIdOrDefault, key, member.getItems().length);
  }

  /**
   * The in-list move both the menu and the chord funnel into: one step or one
   * jump within the movable subsequence, then focus back onto the handle the
   * move just displaced.
   *
   * Resolved fresh by key rather than acting on the row object the render
   * captured, because a move commits against the list as it stands now.
   *
   * A move that would leave the list past either end is refused, and the
   * refusal is announced. Reaching an end is information — it is why the
   * boundary items are marked rather than removed — and a silent no-op is the
   * failure this component exists to stop repeating.
   *
   * @param key - The row to move.
   * @param target - Where to move it.
   * @param method - Which input method asked.
   */
  #move(key: string, target: MoveTarget, method: "menu" | "keyboard") {
    const rows = this.rows;
    const row = rows.find((candidate) => candidate.key === key);
    if (!row?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(row);
    const to = {
      up: from - 1,
      down: from + 1,
      top: 0,
      bottom: seq.length - 1,
    }[target];

    if (to < 0 || to >= seq.length || to === from) {
      this.#announceBoundary(row, target);
      return;
    }

    this.#noteRun(key, method);
    this.#commitSeqMove(method, rows, seq, from, to);
    this.#refocusRow(key);
  }

  /**
   * The drop path for one row target. The payload carries only the dragged
   * row's key; the item and both indices are resolved against the current
   * rows here, so a host that replaced its items mid-drag still lands the
   * drop on the right thing — or refuses it when the key is gone.
   *
   * @param targetKey - The key of the row the drop landed on.
   * @param event - The target modifier's drop payload.
   */
  /**
   * Refuses a row's own in-list drag as a drop candidate, which is what keeps
   * the drop indicator from offering a row a position relative to itself. A
   * same-valued key arriving from another group member is a different item
   * and stays droppable.
   *
   * @param rowKey - This row's key.
   * @param feedback - The target modifier's gate payload.
   */
  @action
  canDropOnRow(
    rowKey: string,
    { source }: { source: { data: Record<string, unknown> } }
  ) {
    return (
      source.data.key !== rowKey || source.data.listId !== this.listIdOrDefault
    );
  }

  @action
  onRowDrop(targetKey: string, { position, source }: DropTargetEvent) {
    const rows = this.rows;
    const targetRow = rows.find((candidate) => candidate.key === targetKey);
    if (!targetRow?.movable) {
      return;
    }

    const sourceListId = source.data.listId as string | undefined;
    if (this.args.group && sourceListId !== this.listIdOrDefault) {
      const toIndex = targetRow.index + (position === "after" ? 1 : 0);
      this.#commitCrossMove(
        sourceListId,
        source.data.key as string,
        toIndex,
        "drag"
      );
      return;
    }

    const sourceRow = rows.find(
      (candidate) => candidate.key === source.data.key
    );
    if (!sourceRow?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(sourceRow);
    let to = seq.indexOf(targetRow);
    if (position === "after") {
      to += 1;
    }
    if (from < to) {
      to -= 1;
    }

    this.#commitSeqMove("drag", rows, seq, from, to);
  }

  /**
   * The drop path for the list's own root element, registered only while the
   * list is an empty group member — the one state with no rows to land on.
   *
   * @param event - The target modifier's drop payload.
   */
  @action
  onEmptyRootDrop({ source }: DropTargetEvent) {
    if (!this.acceptsRootDrops || this.rows.length > 0) {
      return;
    }
    this.#commitCrossMove(
      source.data.listId as string | undefined,
      source.data.key as string,
      0,
      "drag"
    );
  }

  #keyFor(item: T, index: number): string {
    const { key } = this.args;
    if (key === "@index") {
      return String(index);
    }
    if (key) {
      return String(get(item as object, key));
    }
    return guidFor(item);
  }

  /**
   * The single commit both input methods funnel into: splices the move within
   * the movable subsequence, re-interleaves it with the frozen rows (which
   * keep their exact visible indices), suppresses no-ops, calls `@onMove`
   * once, and announces once.
   *
   * @param method - Which input method asked for the move.
   * @param rows - The current row projection.
   * @param seq - The movable rows, in visible order.
   * @param from - The item's index within `seq`.
   * @param to - The destination index within `seq`.
   */
  #commitSeqMove(
    method: ReorderableMove<T>["method"],
    rows: Row<T>[],
    seq: Row<T>[],
    from: number,
    to: number
  ) {
    const move = this.#buildSeqMove(method, rows, seq, from, to);
    if (move) {
      this.#finalize(move);
    }
  }

  /**
   * Builds the normalized move for one step within the movable subsequence,
   * or `null` for a no-op.
   *
   * @param method - Which input method asked for the move.
   * @param rows - The current row projection.
   * @param seq - The movable rows, in visible order.
   * @param from - The item's index within `seq`.
   * @param to - The destination index within `seq`.
   */
  #buildSeqMove(
    method: ReorderableMove<T>["method"],
    rows: Row<T>[],
    seq: Row<T>[],
    from: number,
    to: number
  ): ReorderableMove<T> | null {
    if (to === from) {
      return null;
    }

    const moved = seq[from]!;
    const nextSeq = [...seq];
    nextSeq.splice(from, 1);
    nextSeq.splice(to, 0, moved);

    // Frozen rows keep their visible slots; the movable slots are refilled in
    // the new subsequence order.
    let cursor = 0;
    const proposed = rows.map((row) =>
      row.movable ? nextSeq[cursor++]!.item : row.item
    );
    const toIndex = seq[to]!.index;

    const { items } = this.args;
    const listId = this.listIdOrDefault;
    return {
      method,
      item: moved.item,
      fromList: listId,
      toList: listId,
      fromIndex: moved.index,
      toIndex,
      fromItems: items,
      toItems: items,
      proposedFromItems: proposed,
      proposedToItems: proposed,
    };
  }

  /**
   * The destination half of a cross-list move: resolves the source member
   * through the group, asks it for its removal projection, splices the item
   * into this list's visible order, and finalizes. A source member that
   * unregistered mid-drag, or a key that no longer resolves there, refuses
   * the drop silently.
   *
   * @param sourceListId - The group listId the payload named as its origin.
   * @param key - The dragged row's key in the source member.
   * @param toIndex - The visible landing index in this list.
   * @param method - Which input method asked for the move.
   */
  #commitCrossMove(
    sourceListId: string | undefined,
    key: string,
    toIndex: number,
    method: ReorderableMove<T>["method"]
  ) {
    const { group } = this.args;
    if (!group || !sourceListId) {
      return;
    }
    const member = group.lookupMember(sourceListId);
    const removal = member?.removalProjection(key);
    if (!member || !removal) {
      return;
    }

    // The same slot model as everywhere else: frozen destination rows keep
    // their exact visible indices while the list grows by one slot, and the
    // arriving item joins the movable subsequence at the requested position.
    const rows = this.rows;
    const item = removal.item as T;
    const size = rows.length + 1;
    const empty = Symbol("empty");
    const proposedTo: (T | typeof empty)[] = new Array(size).fill(empty);
    for (const row of rows) {
      if (!row.movable) {
        proposedTo[row.index] = row.item;
      }
    }
    const seqInsert = rows.filter(
      (row) => row.movable && row.index < toIndex
    ).length;
    const queue = rows.filter((row) => row.movable).map((row) => row.item);
    queue.splice(seqInsert, 0, item);
    let cursor = 0;
    for (let index = 0; index < size; index++) {
      if (proposedTo[index] === empty) {
        proposedTo[index] = queue[cursor++]!;
      }
    }

    this.#finalize({
      method,
      item,
      fromList: sourceListId,
      toList: this.listIdOrDefault,
      fromIndex: removal.fromIndex,
      toIndex: proposedTo.indexOf(item),
      fromItems: member.getItems() as readonly T[],
      toItems: this.args.items,
      proposedFromItems: removal.proposedFromItems as readonly T[],
      proposedToItems: proposedTo as readonly T[],
    });
  }

  /**
   * The single exit for every committed move: routes the callback to the
   * group when the list is a member (its own `@onMove` otherwise), honors the
   * veto and the `@announceMove` override, and speaks exactly one
   * announcement — the cross-list variant when an item landed here from
   * another member and this list carries a `@listLabel`.
   *
   * @param move - The normalized move to report.
   */
  #finalize(move: ReorderableMove<T>) {
    if (!this.#dispatch(move)) {
      return;
    }

    if (this.args.announceMove) {
      const custom = this.args.announceMove(move);
      if (custom !== false) {
        this.a11y.announce(custom);
      }
      return;
    }

    const label = this.args.label(move.item);
    const position = move.toIndex + 1;
    const total = move.proposedToItems.length;

    // Mid-run, only where the row now is: the live region re-speaks even an
    // unchanged string, so a held key would otherwise read the same sentence
    // once per step. The full one lands when the run settles.
    if (this.#run) {
      this.a11y.announce(i18n("reorder.position", { position, total }));
      return;
    }

    if (move.fromList !== move.toList && this.args.listLabel) {
      this.a11y.announce(
        i18n("reorder_announcement_cross_list", {
          label,
          list: this.args.listLabel,
          position,
          total,
        })
      );
      return;
    }

    this.#announceMoved(move.item, move.toIndex, total);
  }

  /**
   * Reports a move to its callback owner — the group when the list is a
   * member, its own `@onMove` otherwise.
   *
   * @param move - The normalized move.
   * @returns Whether the move may be announced (`false` when vetoed).
   */
  #dispatch(move: ReorderableMove<T>): boolean {
    const handler = this.args.group?.onMove ?? this.args.onMove;
    return handler?.(move) !== false;
  }

  /**
   * Marks a chord move as part of a run, so a held key speaks position only
   * and the full sentence lands once the key is released. A menu move is
   * always deliberate and single, so it ends any run rather than joining one.
   *
   * @param key - The row being moved.
   * @param method - Which input method asked.
   */
  #noteRun(key: string, method: "menu" | "keyboard") {
    if (this.#run) {
      cancel(this.#run.timer);
      this.#run = null;
    }
    if (method !== "keyboard") {
      return;
    }
    this.#run = {
      key,
      timer: discourseLater(() => {
        if (isDestroying(this)) {
          return;
        }
        const run = this.#run;
        this.#run = null;
        const row = this.rows.find((candidate) => candidate.key === run?.key);
        if (row) {
          this.#announceMoved(row.item, row.index, this.rows.length);
        }
      }, RUN_SETTLE_MS),
    };
  }

  /**
   * Speaks a refused move at either end of the list. The refusal is
   * information rather than an error: it is how a reader learns they have
   * arrived, which a silent no-op never tells them.
   *
   * @param row - The row that could not move.
   * @param target - The direction that was refused.
   */
  #announceBoundary(row: Row<T>, target: MoveTarget) {
    const key = target === "up" || target === "top" ? "at_start" : "at_end";
    this.a11y.announce(
      i18n(`reorder.${key}`, { label: this.args.label(row.item) })
    );
  }

  /**
   * Speaks a committed move in the standard form.
   *
   * @param item - The item that moved.
   * @param index - Its visible index afterwards.
   * @param total - The visible list length afterwards.
   */
  #announceMoved(item: T, index: number, total: number) {
    this.a11y.announce(
      i18n("reorder_announcement", {
        label: this.args.label(item),
        position: index + 1,
        total,
      })
    );
  }

  /**
   * Takes focus back onto a handle after its row moved in the DOM, which
   * blurs it. Without this a keyboard user lands on the body after one move
   * and cannot make a second.
   *
   * @param key - The row key to refocus.
   */
  #refocusRow(key: string) {
    schedule("afterRender", () => {
      if (isDestroying(this) || isDestroyed(this)) {
        return;
      }
      const root = this.#listElement ?? document;
      root
        .querySelector<HTMLElement>(
          `[data-reorderable-key="${CSS.escape(key)}"] .d-reorderable-list__handle`
        )
        ?.focus();
    });
  }

  <template>
    {{#let (dElement this.listTag) as |List|}}
      <List
        class={{dConcatClass
          "d-reorderable-list"
          (if this.acceptsRootDrops "--empty-drop-target")
        }}
        role={{@role}}
        {{this.rootDropTarget}}
        {{this.moveKeys}}
        ...attributes
      >
        {{#if this.menu}}
          <DHeadlessMenu @menu={{this.menu}} />
        {{/if}}
        {{yield to="hint"}}
        {{yield to="header"}}
        {{#if this.rows.length}}
          {{#let (dElement this.itemTag) as |Item|}}
            {{#each this.rows key="key" as |row|}}
              {{! Two whole-row branches rather than one row with a conditional
                  modifier: a conditionally curried modifier is re-created every
                  time the rows recompute, and re-installing the drop target
                  mid-drag leaves the element with a dead registration. Applied
                  statically, the target registers once per row element. }}
              {{#if row.movable}}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                  {{dDragAndDropSource
                    type=this.dragType
                    data=(hash key=row.key listId=this.listIdOrDefault)
                    dragHandle=(this.handleFor row.key)
                  }}
                  {{dDragAndDropTarget
                    accepts=this.dragType
                    canDrop=(fn this.canDropOnRow row.key)
                    onDrop=(fn this.onRowDrop row.key)
                  }}
                  {{this.verifyKeyboardPath}}
                >
                  {{#unless this.isManual}}
                    <HandlePart
                      @row={{row}}
                      @onOpen={{this.openMenu}}
                      @isOpen={{eq this.openKey row.key}}
                      @register={{this.registerHandle}}
                    />
                  {{/unless}}
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                      handle=(if
                        row.yieldControls
                        (component
                          HandlePart
                          row=row
                          onOpen=this.openMenu
                          isOpen=(eq this.openKey row.key)
                          register=this.registerHandle
                        )
                      )
                      remove=(if
                        (and this.rendersRemoveManually row.removable)
                        (component
                          RemovePart
                          row=row
                          icon=this.removeIcon
                          onRemove=this.onRemove
                        )
                      )
                    )
                    to="row"
                  }}
                  {{#if (and this.rendersRemove row.removable)}}
                    <RemovePart
                      @row={{row}}
                      @icon={{this.removeIcon}}
                      @onRemove={{this.onRemove}}
                    />
                  {{/if}}
                </Item>
              {{else}}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                >
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                    )
                    to="row"
                  }}
                </Item>
              {{/if}}
            {{/each}}
          {{/let}}
        {{else}}
          {{yield to="empty"}}
        {{/if}}
        {{#if @allowCreate}}
          {{#if (has-block "create")}}
            {{yield to="create"}}
          {{else}}
            <CreateRow @itemTag={{this.itemTag}} @onCreate={{@onCreate}} />
          {{/if}}
        {{/if}}
      </List>
    {{/let}}
  </template>
}
