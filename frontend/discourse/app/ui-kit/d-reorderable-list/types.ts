import type { ComponentLike } from "@glint/template";

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

  /** The source list's visible items before the move. */
  fromItems: readonly T[];

  /**
   * The destination list's visible items before the move. The same array as
   * `fromItems` for an in-list move.
   */
  toItems: readonly T[];

  /** The source list's proposed visible order after the move. */
  proposedFromItems: readonly T[];

  /**
   * The destination list's proposed visible order after the move. The same
   * array as `proposedFromItems` for an in-list move.
   */
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
   * The pre-wired handle for this row. Yielded only under `@controls="manual"`
   * on a movable row that renders a handle: one with a reachable destination,
   * or any grouped row, whose handle stays the cross-list drag source. It is
   * the drag source and the move menu's trigger at once, so a row yielded one
   * must place it; a development assertion fires when one does not.
   */
  handle?: ComponentLike<{ Element: HTMLElement }>;

  /**
   * The pre-wired remove control. Yielded only under `@controls="manual"` on a
   * movable, removable row when `onRemove` is set; a frozen row yields no
   * controls at all. Carries its own accessible name; everything visual passes
   * through.
   */
  remove?: ComponentLike<{
    Args: { buttonClass?: string };
    Element: HTMLElement;
  }>;
}

/** The context handed to a `@rowClass` function. */
export interface RowClassContext {
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

  /** Whether the member currently refuses every move. */
  disabled: () => boolean;

  /** The member's current translated name. */
  listLabel: () => string | undefined;

  /** The member's current visible items. */
  getItems: () => readonly unknown[];

  /**
   * The member's root element, for resolving which member sits next to which
   * in document order. Undefined before the member has rendered.
   */
  element: () => HTMLElement | undefined;

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
   * @param method - Which input method asked, carried across so a spilled
   *   accelerator is not reported to the consumer as a menu choice.
   */
  acceptMove: (
    sourceListId: string,
    key: string,
    toIndex: number,
    method: "menu" | "keyboard"
  ) => ReorderableMove | null;
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

  /** Lets projections react without tracking the construction-time registry. */
  generation: () => number;

  /** Adds a member; returns its deregistration. Duplicate listIds assert. */
  registerMember: (member: ReorderableGroupMember) => () => void;

  /** The member registered under a listId, if it still exists. */
  lookupMember: (listId: string) => ReorderableGroupMember | undefined;

  /**
   * The other members registered right now, in document order, as the move
   * menu's cross-list destinations. Only enabled members carrying a
   * `listLabel` are returned: an unnamed destination has nothing to put in the
   * menu item, so it stays pointer-only rather than offering "Move to
   * undefined".
   */
  siblings: (listId: string) => { listId: string; listLabel: string }[];

  /**
   * The member immediately before or after another **in reading order**, which
   * is what a row spilling past its own list's end travels into. Disabled
   * members are skipped because they cannot accept the spill.
   *
   * Reading order, not screen position or registration order: the group cannot
   * see where its members landed, and registration order stops matching the
   * document as soon as the members themselves are reordered. `spill` is
   * opt-in because "next in the document" meaning "next on screen" is the
   * consumer's claim to make.
   *
   * @param listId - The member to look out from.
   * @param direction - Which way along the document to look.
   */
  neighbour: (
    listId: string,
    direction: "previous" | "next"
  ) => ReorderableGroupMember | undefined;

  /** The group's single move callback, shared by every member. */
  onMove: (move: ReorderableMove) => void | false;
}

/**
 * The internal per-row view model the component renders from. Rows are
 * recomputed from `@items` on every relevant change, so anything an event
 * handler needs later is re-resolved by `key` rather than captured.
 */
export interface Row<T> {
  item: T;
  key: string;
  index: number;
  movable: boolean;
  isFirst: boolean;
  isLast: boolean;
  /** Whether stepping in this direction lands anywhere the row is not already. */
  canMoveUp: boolean;
  canMoveDown: boolean;

  /**
   * Whether the move menu has a reachable destination. A grouped row may still
   * render a handle as its cross-list drag source when this is false.
   */
  hasDestinations: boolean;

  /**
   * Whether the row renders a handle. What the arrow cursor lands on: the
   * handle where this is true, the row element itself where it is not.
   */
  rendersHandle: boolean;

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

export interface DReorderableListSignature<T> {
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
     * Translated display name for an item. It names the drag handle, the
     * remove control, and the announcements, so every control stays
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
     * Whether a row refused at this list's own end carries on into the
     * adjacent group member instead. Requires `@group`; ignored without one.
     *
     * For members that read as one continuous run: moving down enters the next
     * member at the top and moving up enters the previous one at the bottom,
     * so the row keeps travelling the way it was pushed. The ends of the
     * outermost members still refuse and still announce it.
     *
     * **Setting this asserts that the group runs top to bottom in reading
     * order** — the only order the group can resolve. In a group laid out side
     * by side, Down would carry a row into the list beside it.
     *
     * Off by default, and not only for that reason: members that are genuinely
     * separate lists should stop at their own edges, with "Move to …" in the
     * menu as the deliberate way across.
     */
    spill?: boolean;

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
     * default row is list-shaped (it renders as one extra item element), and
     * wraps its controls in a spanning cell when `@itemTag="tr"`. A table that
     * needs richer cell markup can supply its own `<:create>` block.
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
     *
     * Return a promise to hold both back until the removal has actually
     * happened — what a confirmation in front of it needs, since the handler
     * is otherwise back long before the reader has answered. Either way the
     * list checks that an item really went before speaking, so a handler that
     * declines is not reported as a removal.
     */
    onRemove?: (item: T, index: number) => void | Promise<void>;

    /**
     * Whether an item may be removed, defaulting to all of them.
     *
     * Mirrors `@movable`, which renders no handle on a row that cannot move:
     * a row that cannot be removed renders no remove control either. A
     * permanently protected row would otherwise carry a dead tab stop that
     * announces itself as unavailable on every pass.
     */
    removable?: (item: T) => boolean;

    /**
     * The remove control's icon. One list-level argument rather than a
     * per-row one, because the control is placed by the list in every mode
     * except manual.
     */
    removeIcon?: string;

    /**
     * The remove control's button weight, defaulting to `btn-flat`. List-level
     * for the same reason as `removeIcon`: the control is placed by the list in
     * every mode except manual, where `controls.remove` takes its own
     * `@buttonClass` to override this.
     */
    removeButtonClass?: string;

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
export type MoveTarget = "up" | "down" | "top" | "bottom";
