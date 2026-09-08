import type { DisabledItems } from "discourse/ui-kit/-internals/cursor/item-scope";
import type { Orientation } from "discourse/ui-kit/-internals/cursor/navigation";

/**
 * Which of the practice page's two focus-management strategies the group uses:
 * a roving tabindex that moves DOM focus, or `aria-activedescendant` on a controller that keeps
 * it. Named for the strategies rather than for selection, which the page is emphatic is a
 * different concept.
 */
export type DRovingFocusStrategy = "roving-tabindex" | "active-descendant";

/**
 * Controls for moving the cursor to a live item in the roving-focus group.
 *
 * The `focus*` members return whether they landed on an item — `false` when the group is
 * currently empty (e.g. a re-render dropped every item), when the index fails the member's own
 * numeric predicate, or, for
 * {@link DRovingFocusApi.focusLogicalIndex}, when the target row is not mounted — so the caller
 * can fall back. The two stepping members are the exception: they report a three-valued
 * {@link DRovingFocusStepResult}, because "already at the end" and "nothing to step through" want
 * different fallbacks. {@link DRovingFocusApi.reannounceActive} moves nothing and carries its own
 * return contract.
 */
export interface DRovingFocusApi {
  /** Moves the cursor to the first navigable item. */
  focusFirst(): boolean;
  /** Moves the cursor to the last navigable item. */
  focusLast(): boolean;
  /**
   * Moves the cursor to a position among the navigable items, clamping an out-of-range index to
   * the first or last one (and still reporting `true`). A non-integer index reports `false`.
   */
  focusIndex(index: number): boolean;
  /**
   * Move the cursor to the item whose `data-logical-index` — or, failing that, `data-index` — is
   * the given ABSOLUTE logical index. This is the addressing a windowed list needs, where the
   * mounted items are a slice of a much larger set and their NodeList position is not their true
   * index. The stamp is compared numerically, so a zero-padded value still matches. Returns
   * `false` when that logical index is not currently mounted (the caller must scroll it into view
   * first). When no item carries either attribute (a non-windowed group) the index is treated as
   * positional — but bounds-checked rather than clamped, so an out-of-range index reports `false`
   * and moves nothing, unlike {@link DRovingFocusApi.focusIndex}.
   */
  focusLogicalIndex(index: number): boolean;
  /**
   * Active mode only — makes assistive tech read the active item again without moving the
   * cursor, by dropping `aria-activedescendant` and restoring it a tick later. Re-asserting
   * the same value is a no-op, so a change is the only thing that can be observed.
   *
   * For when the item itself is unchanged but what it says about its context is not: a row
   * whose `aria-setsize` moved from 2 to 1 under a stationary cursor reports a different
   * position in a different set, and nothing re-reads it. Returns `false` when there is no
   * cursor to re-read.
   */
  reannounceActive(): boolean;
  /**
   * Steps the cursor one item forward, as the corresponding arrow key would. `axis` picks which
   * axis to travel in a grid; omitted, it follows the group's own orientation.
   *
   * Unlike the keyboard path this suppresses the EDGE callback — `onBoundary` announces that a
   * *reader* pushed against a boundary, which a programmatic call has not done.
   * `onActiveChange` still fires on a real move, because the cursor really did move.
   */
  focusNext(axis?: DRovingFocusAxis): DRovingFocusStepResult;
  /** The backward counterpart of {@link DRovingFocusApi.focusNext}, with the same contract. */
  focusPrevious(axis?: DRovingFocusAxis): DRovingFocusStepResult;
  /** The items the cursor may legally land on, in DOM order. */
  items(): HTMLElement[];
  /** The item the cursor currently sits on, or `null` when there is no cursor. */
  currentItem(): HTMLElement | null;
  /**
   * The position of `item` within {@link DRovingFocusApi.items}, or `-1` when it is not a member.
   *
   * Deliberately resolved against that list rather than by re-querying the DOM: raw selector
   * order counts items the cursor can never land on, so an index derived that way addresses a
   * different item than the one it names as soon as a single hidden or disabled match sits
   * earlier in the container.
   */
  indexOf(item: HTMLElement): number;
  /**
   * Moves the cursor onto a specific element, returning `false` (and moving nothing) when it is
   * not one of {@link DRovingFocusApi.items}. Addressing by element rather than by index is what
   * lets a caller hold a reference across a re-render without recomputing positions.
   */
  focusElement(item: HTMLElement): boolean;
  /**
   * Active mode only — drops the cursor entirely, so nothing is highlighted and
   * `aria-activedescendant` points at nothing until the next move seeds a new one.
   *
   * There is deliberately no focus-mode counterpart. There the cursor IS DOM focus, and the
   * cursor is resolved from `document.activeElement` first, so a clear that does not blur would
   * clear nothing — while one that did blur would strand focus on `<body>`, which is worse than
   * the state it set out to fix.
   *
   * @returns Whether there was a cursor to drop.
   */
  clear(): boolean;
}

/**
 * A single navigation axis. `"grid"` is absent by construction: it names a space that allows
 * both axes, not a direction a step can travel.
 */
export type DRovingFocusAxis = Exclude<Orientation, "grid">;

/**
 * Where the cursor goes when no surviving one can be kept. Each value names its own fallback:
 * `"selected-or-first"` prefers a marked item and settles for the first, `"selected-or-none"`
 * prefers a marked item and settles for nothing.
 */
export type DRovingFocusEntry =
  | "none"
  | "first"
  | "selected-or-first"
  | "selected-or-none";

/**
 * The outcome of an API-driven step: `"moved"` when the cursor advanced, `"edge"` when a cursor
 * exists but is already against a boundary, and `"unavailable"` when the group has no items at
 * all. Three-valued so a caller can tell "the run ended here" from "there is no run here" and
 * fall back accordingly.
 */
export type DRovingFocusStepResult = "moved" | "edge" | "unavailable";

export interface DRovingFocusArgs {
  /**
   * Which focus-management strategy the group uses. Default `"roving-tabindex"`.
   *
   * Shape dictated by: Managing Focus in Composites, which names these two strategies.
   */
  focusStrategy?: DRovingFocusStrategy;
  /**
   * Navigation axes; `"grid"` (default) allows both, `"horizontal"`/`"vertical"` one. Ignored
   * under `focusStrategy="active-descendant"`, which is single-axis by construction: it leaves the
   * horizontal arrows to its controller's caret, so the vertical axis is always the live one
   * there whatever this says.
   */
  orientation?: Orientation;
  /** CSS selector matching the navigable items within the container. */
  itemSelector: string;
  /**
   * Called when an item is activated: Enter or Space in `"roving-tabindex"` mode, Enter only in `"active-descendant"`
   * mode, where Space belongs to the controller's caret. Only fires when the key landed on the
   * item itself, so a control nested inside an item keeps its own activation.
   *
   * See {@link DRovingFocusArgs.onActiveChange} for choosing between wiring selection to this and
   * wiring it to the cursor.
   */
  onActivate?: (item: HTMLElement, event: KeyboardEvent) => void;
  /**
   * Called whenever the cursor is placed on an item, or with `null` (and no `meta`) when the
   * highlight is cleared. `meta.pointer` is `true` when a pointer press placed it, which a
   * consumer can use to move the cursor without revealing it. Fires even when the cursor is
   * re-placed on the item it already held.
   *
   * Driven by actual cursor movement, so in `"roving-tabindex"` mode it reports arrow keys, pointer
   * presses and the API — not the tab stop being seeded or re-seeded, which moves no cursor —
   * and the `null` clear is an active-mode signal only.
   *
   * With {@link DRovingFocusArgs.onActivate} this pair is the practice page's
   * selection-follows-focus switch, which is why both exist rather than one. Wire selection here
   * to have it follow the cursor, or to `onActivate` to make the reader commit deliberately. The
   * page's "Deciding When to Make Selection Automatically Follow Focus" is the guidance on which
   * to choose, and a radio group and a listbox land on opposite answers.
   */
  onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;
  /**
   * Called when an arrow key would move the cursor past an end of the GROUP, with `wrap` false
   * and a cursor already present; wrapping suppresses it. Deliberately reports the boundary
   * rather than prescribing a response: handing off to a neighbouring control and fetching more
   * rows are both legitimate, and which one applies is the consumer's business.
   *
   * `direction` is LOGICAL — `"forward"` means past the last item in DOM order, whichever arrow
   * key produced it. In a right-to-left group the forward horizontal key is ArrowLeft, so a
   * consumer handing off to a neighbouring control must resolve the physical side itself.
   *
   * `axis` names the axis travelled, and the two are not symmetric. `"horizontal"` requires
   * `"horizontal"` or `"grid"` orientation and never fires under `focusStrategy="active-descendant"`, which
   * leaves the horizontal arrows to its controller's caret. `"vertical"` requires `"vertical"`
   * or `"grid"` in `"roving-tabindex"` mode, but fires in `"active-descendant"` mode whatever `orientation` says,
   * because there the vertical axis is always the live one. A consumer that means "leave the
   * widget" must therefore branch on `axis` rather than treat every boundary alike.
   *
   * Under a multi-column grid a ROW edge is not a group edge, so an interior row never fires
   * this — otherwise a consumer would be dragged away mid-traversal.
   */
  onBoundary?: (
    direction: "forward" | "backward",
    axis: DRovingFocusAxis
  ) => void;
  /**
   * The size of the logical index space addressed by `data-logical-index` or `data-index`,
   * including disabled rows. Setting it is what makes PageUp/PageDown page: without it those keys
   * are left alone entirely so a scrollable container pages natively, Home and End address the
   * mounted items positionally, and {@link DRovingFocusArgs.onJump} is never called.
   */
  logicalCount?: number;
  /**
   * Called when a logical jump target is outside the currently-mounted item window, so the
   * consumer can mount and focus that row. Without it an off-window jump cannot be serviced, so
   * the key is left un-prevented rather than becoming a dead key.
   */
  onJump?: (target: number, direction: "forward" | "backward") => void;
  /**
   * Registers stable controls for moving the cursor, and receives `null` on teardown or when
   * superseded by a different callback. Compared by identity, so pass a stable reference — an
   * inline arrow re-registers on every render, and would take a `null` each time first.
   */
  onRegisterApi?: (api: DRovingFocusApi | null) => void;
  /** Whether navigation wraps at the ends (default `false` = clamp). */
  wrap?: boolean;
  /**
   * Focus mode: whether one item is reachable with Tab (default `true`).
   *
   * Shape dictated by: Navigation Between Components, the single-tab-stop contract.
   */
  tabStop?: boolean;
  /**
   * Focus mode: whether removing the item that holds focus moves the cursor to the item that
   * took its place, rather than letting focus fall to `body` (default `true`).
   *
   * Only fires when focus was genuinely lost, so a reader who moved focus elsewhere before the
   * removal keeps it. When the group empties entirely nothing happens: where focus should go
   * with no items left is the consumer's decision.
   *
   * **Depends on the modifier being told the items changed.** Reconciliation runs from
   * `modify()`, which re-runs only when a named argument does, so a group whose items come from
   * state this cannot observe must pass {@link DRovingFocusArgs.itemsKey}. Without it there is
   * no failure to see: focus simply falls to `body` as though this were off. Defaulting to
   * `true` does not make it independent of that contract.
   *
   * Turn it off to place focus yourself, e.g. onto a control outside the group.
   */
  restoreLostFocus?: boolean;
  /**
   * Class toggled on the active item in `"active-descendant"` mode.
   *
   * Shape dictated by: Discernible and Predictable Focus, where the indicator must stay visible.
   */
  activeClass?: string | null;
  /**
   * A reactive key (e.g. the filter string) that re-reconciles the cursor when it changes. The
   * modifier only re-runs when a named arg does, so a group whose items change from state the
   * modifier cannot see needs this to keep its cursor and tab stop correct.
   */
  itemsKey?: unknown;
  /**
   * A reactive key identifying the *question* the items answer. Reconciling normally keeps the
   * cursor on the active item whenever it survives the change, which is right when rows are
   * appended or revised but wrong when the list becomes a different result set: a row that
   * happens to match both queries would hold the cursor deep in the new list. Change this and
   * the cursor stops tracking the survivor: in `"active-descendant"` mode it re-seeds per
   * {@link DRovingFocusArgs.entryFocus}; in `"roving-tabindex"` mode the tab stop is picked afresh rather
   * than left on a surviving row.
   *
   * Key it on the query the *rendered* items answer, not the one being typed — a list that
   * keeps its old rows visible during an async reload would otherwise re-seed against them.
   */
  resetKey?: unknown;
  /**
   * Active mode: the element that keeps DOM focus, as an `HTMLElement` or a document-wide
   * selector. Its editability changes the key contract — a text input keeps Home/End for its
   * caret, while a non-editable controller (a select-only combobox) hands them to the listbox.
   * `null` is a legitimate transient while the controller has yet to render.
   *
   * A selector is resolved when the arguments change, not continuously, so a controller that is
   * destroyed and re-created under the same selector must be signalled — pass the element itself,
   * or change another argument — or the listener stays on the detached node.
   *
   * Shape dictated by: Managing Focus in Composites Using aria-activedescendant.
   */
  controllerElement?: HTMLElement | string | null;
  /**
   * Where the cursor goes when there is no surviving one to keep. Default
   * `"selected-or-first"`.
   *
   * Each value names its own fallback, because the fallback is the whole distinction:
   *
   * - `"none"` — nothing becomes active.
   * - `"first"` — the first navigable item, whatever is marked.
   * - `"selected-or-first"` — the marked item, else the first.
   * - `"selected-or-none"` — the marked item, else nothing.
   *
   * "Marked" means `aria-selected="true"`, `aria-checked="true"` or an `aria-current` token other
   * than `"false"` or empty. The consumer owns those attributes; this only reads them.
   *
   * The two modes answer different questions with the same values. Under
   * `focusStrategy="roving-tabindex"` this is the entry convention from the keyboard-interface practice:
   * where focus lands when Tab moves into the composite. Toolbars and menubars enter on the
   * first control (`"first"`), while listboxes, radio groups, tabs and trees enter on the
   * selected one. Under `focusStrategy="active-descendant"` it is instead what is active when a popup
   * opens, which the combobox pattern leaves to the author: a list that waits for the reader to
   * type or arrow wants `"none"`, and one that should not pre-highlight an arbitrary row but
   * should still restore a held value wants `"selected-or-none"`.
   *
   * A surviving cursor always outranks this. In focus mode an established tab stop is kept, and
   * in active mode a still-present active item is kept, so this only decides the *first* entry
   * and re-entry after a {@link DRovingFocusArgs.resetKey} change.
   *
   * In focus mode the two no-fallback values leave the group with no tab stop unless the author
   * supplies one, which is a deliberate way to hand that choice back rather than an oversight.
   *
   * Shape dictated by: Navigation Inside Components, and its three entry conventions.
   */
  entryFocus?: DRovingFocusEntry;
  /**
   * Whether {@link DRovingFocusArgs.entryFocus}'s first-item fallback skips items the consumer
   * has marked. Default `false`.
   *
   * The case it exists for is a multi-select whose Enter *toggles*: seeding the fallback onto an
   * already-selected row arms the very first Enter to discard a value the reader never navigated
   * to. Arrow keys still reach those rows, where removing them is deliberate.
   *
   * Constrains the fallback only, never a restored selection: the reader chose that row
   * themselves and can see it is marked, so it is seeded even where activating it would remove
   * it.
   *
   * **Scoped to a popup that seeds itself, and deliberately NOT the listbox convention.** The
   * listbox pattern says the opposite for a multi-select group receiving focus — land on the
   * first selected option, returning the reader to their own selection — and accepts that the
   * next toggle key removes it, because they tabbed in on purpose and can see where the cursor
   * is. This exists for the case that pattern does not cover: a combobox popup where the cursor
   * is placed automatically, focus is still in the input, and Enter reads as "take this" rather
   * than "toggle this", so an auto-seeded cursor on a held row silently drops a value the reader
   * never navigated to. Reach for `entryFocus="selected-or-first"` in a listbox; reach for this
   * in a popup.
   */
  fallbackSkipsMarked?: boolean;
  /**
   * Whether the cursor may rest on an item the consumer has marked `aria-disabled="true"`.
   * Default `"skip"`, which is what a listbox or combobox wants.
   *
   * The practice page's section on the focusability of disabled controls draws a distinction
   * this collapses by default: `disabled` is for state a reader can infer from context, while
   * `aria-disabled` is for state that must stay discoverable, because moving focus to a control
   * is how a screen reader user finds out it exists at all. Toolbars and menus are the patterns
   * that need it.
   *
   * `"focusable"` widens where the cursor may LAND, and nothing else. A disabled item is still
   * never activated, so {@link DRovingFocusArgs.onActivate} does not fire on one under either
   * value. Reachable and operable are separate questions and only the first is opened here.
   *
   * Note the asymmetry with native `disabled`, which no value can override: the platform
   * refuses focus to such a control outright, so targeting one would strand focus on `body`
   * rather than move it. Only the ARIA spelling is affected.
   *
   * Shape dictated by: Focusability of disabled controls.
   */
  disabledItems?: DisabledItems;
  /**
   * Called for an arrow press on the axis this group does NOT navigate, so the keys a
   * single-axis composite leaves unused become available without every consumer re-deriving
   * them. A `"vertical"` group reports the horizontal arrows and a `"horizontal"` group reports
   * the vertical ones; a `"grid"` navigates both and so never reports either.
   *
   * Deliberately reports a direction rather than prescribing a response, exactly as
   * {@link DRovingFocusArgs.onBoundary} does, because the meaning varies per pattern: expand
   * and collapse for a tree, enter and exit a cell for a treegrid, open and close a submenu for
   * a menubar. Those semantics are the consumer's; only the key handling is shared.
   *
   * `direction` is LOGICAL and already mirrored where the axis mirrors. In a right-to-left
   * group the forward horizontal key is ArrowLeft, which is what a reader expects when the
   * arrow pointing at a row's children is the one that opens them. The vertical axis does not
   * mirror, so a horizontal group reports ArrowDown as `"forward"` whatever the direction.
   *
   * Return `true` when the press was acted on and the modifier will consume it. Return nothing
   * to leave it un-prevented so it can bubble, which is what a leaf node or an
   * already-collapsed row needs. Never fires while the cursor rests nowhere, since there would
   * be no item to report it against.
   */
  onCrossAxis?: (
    direction: "forward" | "backward",
    item: HTMLElement,
    event: KeyboardEvent
  ) => boolean | void;
  /**
   * Whether typing printable characters moves the cursor to the item whose accessible NAME
   * starts with what was typed. Default `false`.
   *
   * The practice page specifies this identically for listbox, tree and menu, which is why it
   * lives here rather than in each of them. Matching is on the accessible name — what assistive
   * technology announces — rather than on text content, so an item labelled by `aria-label` or
   * by a pseudo-element is reachable exactly as it is heard.
   *
   * Comparison folds case and diacritics, so `e` finds `Éclair`. Successive characters extend
   * the query and narrow the match; the query lapses after a short pause, and Space extends it
   * rather than activating while one is under way.
   *
   * Declined when the DOM holds only part of the set — {@link DRovingFocusArgs.logicalCount}
   * exceeding the mounted count — because answering from those rows returns a nearer match
   * while a truer one sits off-window, which is worse than not answering. A consumer that wants
   * it there has to search its own data, which needs a callback this does not yet have.
   *
   * A logical count alone does not decline it: that argument also drives paging, and a
   * fully-mounted list may set it for that alone. Note the completeness test relies on the
   * consumer declaring the count honestly — a group that windows without saying so is searched
   * as though it were whole, and nothing here can detect that. The same honesty applies in
   * reverse: a selector-matched row that is not yet searchable — a placeholder awaiting its
   * content — still counts as mounted, so keep placeholders out of `itemSelector` (or out of
   * the count) while they are empty.
   */
  typeAhead?: boolean;
}

export interface DRovingFocusSignature {
  Element: HTMLElement;
  Args: {
    Named: DRovingFocusArgs;
    Positional: [];
  };
}
