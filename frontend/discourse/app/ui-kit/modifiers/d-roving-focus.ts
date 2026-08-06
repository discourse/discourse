import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
import { cancel, next as nextRunloop } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";

type SelectionMode = "focus" | "active";
type Orientation = "grid" | "horizontal" | "vertical";

/**
 * The result of one navigation step.
 *
 * The two edges are deliberately distinct. `"group-edge"` means the cursor is at the end of the
 * whole group, which is what `onExit`/`onEdgeReach` report so a consumer can hand off elsewhere.
 * `"row-edge"` means the cursor did not move but has not left anything either: the key is consumed
 * and nothing is reported. That covers a closed grid row — a consumer that moves focus away on
 * `onExit` must not be triggered from the middle of a grid — and also a wrap that resolved back
 * onto the cursor, where `wrap` has promised no edge will be reported.
 */
type StepOutcome =
  | { kind: "move"; index: number }
  | { kind: "row-edge" }
  | { kind: "group-edge" };

/**
 * Controls for moving the cursor to a live item in the roving-focus group.
 *
 * The `focus*` members return whether they landed on an item — `false` when the group is
 * currently empty (e.g. a re-render dropped every item), when the index is not a number, or, for
 * {@link DRovingFocusApi.focusLogicalIndex}, when the target row is not mounted — so the caller
 * can fall back. {@link DRovingFocusApi.reannounceActive} moves nothing and carries its own
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
}

interface DRovingFocusArgs {
  /** `"focus"` (roving tabindex, default) or `"active"` (`aria-activedescendant`). */
  selectionMode?: SelectionMode;
  /**
   * Navigation axes; `"grid"` (default) allows both, `"horizontal"`/`"vertical"` one. Ignored
   * under `selectionMode="active"`, which is single-axis by construction: it leaves the
   * horizontal arrows to its controller's caret, so the vertical axis is always the live one
   * there whatever this says.
   */
  orientation?: Orientation;
  /**
   * CSS selector matching the navigable items within the container. Required in practice —
   * without it the modifier matches nothing and no key does anything.
   */
  itemSelector?: string;
  /**
   * Column count override, as a number or a `() => number` re-read on each keydown. Applies only
   * under `orientation="grid"` in `"focus"` mode, where it replaces the CSS derivation entirely;
   * every other configuration has a single axis and ignores it. Use it for a tile layout that is
   * not a real CSS grid.
   */
  columns?: number | (() => number) | null;
  /**
   * Called when an item is activated: Enter or Space in `"focus"` mode, Enter only in `"active"`
   * mode, where Space belongs to the controller's caret. Only fires when the key landed on the
   * item itself, so a control nested inside an item keeps its own activation.
   */
  onActivate?: (item: HTMLElement, event: KeyboardEvent) => void;
  /**
   * Called whenever the cursor is placed on an item, or with `null` (and no `meta`) when the
   * highlight is cleared. `meta.pointer` is `true` when a pointer press placed it, which a
   * consumer can use to move the cursor without revealing it. Fires even when the cursor is
   * re-placed on the item it already held.
   *
   * Driven by actual cursor movement, so in `"focus"` mode it reports arrow keys, pointer
   * presses and the API — not the tab stop being seeded or re-seeded, which moves no cursor —
   * and the `null` clear is an active-mode signal only.
   */
  onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;
  /**
   * Called at a horizontal end of the GROUP when `wrap` is false and a cursor is present;
   * wrapping suppresses it. Requires `"horizontal"` or `"grid"` orientation. Under a
   * multi-column grid a row edge is not a group edge, so an interior row does not fire this.
   *
   * The direction is LOGICAL — `"forward"` means past the last item in DOM order, whichever
   * arrow key produced it. In a right-to-left group that is ArrowLeft, so a consumer handing off
   * to a neighbouring control must resolve the physical side itself.
   *
   * Never fires under `selectionMode="active"`, which does not claim the horizontal arrows.
   */
  onExit?: (direction: "forward" | "backward") => void;
  /**
   * The vertical counterpart to {@link DRovingFocusArgs.onExit}: called when ArrowDown or ArrowUp
   * would move past the edge with `wrap` false and a cursor present. `"forward"` is down,
   * `"backward"` is up. Requires `"vertical"` or `"grid"` orientation in `"focus"` mode; in
   * `"active"` mode the vertical axis is always live, whatever `orientation` says. A windowed
   * list uses it to scroll or fetch the next rows before the cursor reaches the true end.
   */
  onEdgeReach?: (direction: "forward" | "backward") => void;
  /**
   * The total number of navigable logical rows. Setting it is what makes PageUp/PageDown page:
   * without it those keys are left alone entirely so a scrollable container pages natively, Home
   * and End address the mounted items positionally, and {@link DRovingFocusArgs.onJump} is never
   * called.
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
  /** Focus mode: whether one item is reachable with Tab (default `true`). */
  tabStop?: boolean;
  /** Class toggled on the active item in `"active"` mode. */
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
   * the cursor stops tracking the survivor: in `"active"` mode it re-seeds per
   * {@link DRovingFocusArgs.autoActivateSelected}/{@link DRovingFocusArgs.autoActivateFirst}, or
   * clears when neither is set; in `"focus"` mode the tab stop is picked afresh rather than left
   * on a surviving row.
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
   */
  controllerElement?: HTMLElement | string | null;
  /**
   * Active mode only — when true, highlight the first item whenever the cursor has none
   * (initial render, or the active item dropped out on a re-filter), so Enter selects it
   * without an ArrowDown. The WAI-ARIA "list autocomplete with automatic selection"
   * combobox pattern. Default `false` (the cursor starts empty until an Arrow keypress).
   *
   * Constrained by {@link activationRemovesSelected}, which excludes items the seed must not
   * land on.
   */
  autoActivateFirst?: boolean;
  /**
   * Active mode only — when the cursor has none, prefer the item marked `aria-selected="true"`
   * over the first one. Restores the user's existing choice when a list is reopened, rather than
   * pointing them at an unrelated row. Takes priority over {@link autoActivateFirst}, so a list
   * that deliberately starts without a cursor still gets its selection back.
   *
   * The consumer owns `aria-selected`; this only reads it, mirroring what the tab-stop seeding
   * already does in focus mode. Default `false`.
   *
   * Deliberately NOT constrained by {@link DRovingFocusArgs.activationRemovesSelected}: a
   * restored selection is seeded even where activating it would remove it, on the grounds that
   * the reader chose that row themselves and can see it is selected. The constraint applies only
   * to {@link DRovingFocusArgs.autoActivateFirst}, which would otherwise land on a selected row
   * they never navigated to.
   */
  autoActivateSelected?: boolean;
  /**
   * Active mode only — whether activating an already-selected item *removes* it, as a
   * multi-select toggle does. When true, {@link autoActivateFirst} skips selected items, because
   * seeding one would arm the very first Enter to discard a value the reader never navigated to.
   * Arrow keys still reach those items, where removing them is deliberate.
   *
   * Distinct from {@link autoActivateSelected} being off, which is a *preference* (a filtering
   * single-select wants the top match rather than the held row) and not a hazard: there,
   * activating the held item merely re-confirms it. Default `false`.
   */
  activationRemovesSelected?: boolean;
}

interface DRovingFocusSignature {
  Element: HTMLElement;
  Args: {
    Named: DRovingFocusArgs;
    Positional: [];
  };
}

/**
 * Keyboard navigation for a one-dimensional list or a two-dimensional grid of
 * items, in DOM order. It implements the two WAI-ARIA "single tab stop" patterns
 * from one engine, chosen with `selectionMode`:
 *
 * - `"focus"` (the default) — a roving tabindex. Exactly one item is reachable with Tab
 *   (`tabindex="0"`) and the rest are set to `tabindex="-1"`; with `tabStop=false` every item is
 *   set to `-1`. Arrow keys move real DOM focus between items and update tabindex along with it.
 *   Use this when the active item should itself hold focus (a tile grid, a toolbar).
 * - `"active"` — `aria-activedescendant`. DOM focus stays on a separate controller
 *   element (typically a text input); arrow keys move a *virtual* highlight through
 *   the items by pointing the controller's `aria-activedescendant` at the active
 *   item and toggling `activeClass` on it. Use this for a combobox where the user
 *   must keep typing while navigating results.
 *
 * The single-tab-stop invariant holds as long as the modifier is told when the items change:
 * it only re-runs when a named argument does, so a group whose rows come from state it cannot
 * see must pass `itemsKey`.
 *
 * Navigation is always DOM order. Row and column arithmetic uses the items that occupy a layout
 * position — a disabled or `visibility: hidden` row still fills its cell, so counting only the
 * navigable ones would land a vertical step a column adrift. The column count is derived from
 * the resolved `grid-template-columns` at keydown time, never from element geometry
 * (`offsetTop`/`offsetLeft`), so a responsive grid that reflows is handled without
 * re-configuration; passing `columns` opts out of that derivation.
 *
 * The modifier is deliberately role-agnostic: the consumer supplies the container
 * and item roles (`role="listbox"`/`"grid"` + `role="option"`, and, for active mode,
 * `role="combobox"` + `aria-controls` on the controller). The modifier owns only the
 * keyboard cursor — `tabindex` (focus mode) or `aria-activedescendant` + `activeClass`
 * plus an `id` minted onto any highlighted item that lacks one (active mode). It never touches
 * `aria-selected`, which expresses a *chosen value* (a separate concept the consumer owns).
 *
 * @example A toolbar whose buttons are navigated with the left and right arrows.
 * ```gjs
 * <div role="toolbar" {{dRovingFocus orientation="horizontal" itemSelector="[role=button]"}}>
 *   <button role="button">Bold</button>
 *   <button role="button">Italic</button>
 * </div>
 * ```
 *
 * @example A combobox whose input keeps focus while the arrows move a virtual highlight.
 * ```gjs
 * <input id="q" role="combobox" aria-controls="results" />
 * <div
 *   id="results"
 *   role="listbox"
 *   {{dRovingFocus
 *     selectionMode="active"
 *     controllerElement="#q"
 *     itemSelector="[role=option]"
 *     activeClass="--active"
 *     itemsKey=this.query
 *     onActivate=this.choose
 *   }}
 * >
 *   {{#each this.results key="id" as |result|}}
 *     <div role="option" id={{result.id}}>{{result.label}}</div>
 *   {{/each}}
 * </div>
 * ```
 */
export default class DRovingFocusModifier extends Modifier<DRovingFocusSignature> {
  /** The element the modifier is attached to (the items' container). */
  #element: HTMLElement | null = null;

  #orientation: Orientation = "grid";
  #itemSelector?: string;
  #columnsOverride: number | (() => number) | null = null;
  #onActivate?: (item: HTMLElement, event: KeyboardEvent) => void;
  #onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;
  #onExit?: (direction: "forward" | "backward") => void;
  #onEdgeReach?: (direction: "forward" | "backward") => void;
  #logicalCount?: number;
  #onJump?: (target: number, direction: "forward" | "backward") => void;
  #wrap = false;
  #tabStop = true;
  #activeClass: string | null = null;
  #autoActivateFirst = false;
  #autoActivateSelected = false;
  #activationRemovesSelected = false;

  /** The element keydown is bound to: the container (focus) or controller (active). */
  #listenElement: HTMLElement | null = null;
  #pointerElement: HTMLElement | null = null;

  /** Armed only while a seed is owed to a container that had no items yet. */
  #pendingSeed: MutationObserver | null = null;

  /**
   * The modes this instance has actually operated in. Teardown consults it so a mode that never
   * ran cannot hand back attributes it never wrote — `#mode` starts at `"focus"`, so an
   * active-mode-only group would otherwise strip every author-supplied `tabindex` on its first
   * run and turn items the author had deliberately excluded into tab stops.
   */
  #enteredModes = new Set<SelectionMode>();

  /** Whether `modify()` has run at least once, so the first run is not mistaken for a reset. */
  #hasRun = false;

  /**
   * Monotonic counter behind minted ids. Never reset, so an id cannot be reissued to a second
   * element while the first still carries it — which the set's size would allow after a mode or
   * selector change clears the bookkeeping.
   */
  #mintCounter = 0;

  /** Pending restore of a dropped `aria-activedescendant` — see `reannounceActive`. */
  #reannounceTimer?: ReturnType<typeof nextRunloop>;

  /**
   * The last `resetKey` seen. The sentinel is a fresh symbol so the first `modify()` always counts
   * as a change — harmless, since there is no cursor yet to preserve, and it keeps the "unset"
   * case from colliding with a consumer that legitimately passes `undefined`.
   */
  #resetKey: unknown = Symbol("unset");

  #mode: SelectionMode = "focus";

  /** Stable controls registered with the consumer for moving focus into the group. */
  #api: DRovingFocusApi = {
    focusFirst: () => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      this.#setActive(items[0]);
      return true;
    },
    focusLast: () => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      this.#setActive(items[items.length - 1]);
      return true;
    },
    focusIndex: (index) => {
      const items = this.#items();
      // A non-finite or fractional index would survive the clamp below and dereference a hole in
      // the list. The contract is a boolean, so report the miss rather than throwing.
      if (!items.length || !Number.isInteger(index)) {
        return false;
      }
      const last = items.length - 1;
      this.#setActive(items[Math.max(0, Math.min(index, last))]);
      return true;
    },
    focusLogicalIndex: (index) => {
      const items = this.#items();
      if (!items.length || !Number.isFinite(index)) {
        return false;
      }
      // Prefer an explicit logical ordinal (`data-logical-index`) where a consumer stamps one,
      // so a windowed list with non-option rows can address options independently of the raw
      // virtualizer index; fall back to `data-index` for consumers that stamp only that.
      // Compared numerically, so a zero-padded or whitespace-padded stamp still matches and a
      // very large index does not fail against its own exponential notation.
      const match = items.find((el) => {
        const stamp = el.dataset.logicalIndex ?? el.dataset.index;
        return stamp !== undefined && Number(stamp) === index;
      });
      if (match) {
        this.#setActive(match);
        return true;
      }
      // No item carries an index at all: a non-windowed group, so the logical index IS the
      // positional index. If some do but none matched, the target sits outside the mounted
      // window and cannot be focused here.
      if (
        items.every(
          (el) =>
            el.dataset.logicalIndex === undefined &&
            el.dataset.index === undefined
        )
      ) {
        // Bounds-checked rather than delegated blindly: `focusIndex` CLAMPS, so an off-window
        // target would land on the nearest mounted row and report success, telling the caller
        // the jump was serviced when it never happened.
        return index >= 0 && index < items.length
          ? this.#api.focusIndex(index)
          : false;
      }
      return false;
    },
    reannounceActive: () => {
      const id = this.#activeId;
      const listenElement = this.#listenElement;
      if (this.#mode !== "active" || !id || !listenElement) {
        return false;
      }
      // The item has to still be there. A cursor id outlives its row — a re-render can drop every
      // item before this is reconciled — and dropping the attribute for a row that no longer
      // exists reads as success to the caller while reading nothing to anyone.
      if (!this.#items().some((el) => el.id === id)) {
        return false;
      }

      listenElement.removeAttribute("aria-activedescendant");
      // A second call before the first flushes would otherwise strand the earlier timer, leaving
      // `cleanup()` able to cancel only the last one.
      if (this.#reannounceTimer) {
        cancel(this.#reannounceTimer);
      }
      this.#reannounceTimer = nextRunloop(() => {
        this.#reannounceTimer = undefined;
        // A real cursor move in the meantime has already pointed the attribute somewhere, and
        // restoring the old id would drag the reader back. The controller must also still be the
        // one this group drives: a swap between scheduling and flushing would otherwise leave the
        // OLD controller advertising an active descendant it no longer controls.
        if (
          this.#listenElement === listenElement &&
          this.#activeId === id &&
          this.#items().some((el) => el.id === id)
        ) {
          listenElement.setAttribute("aria-activedescendant", id);
        }
      });
      return true;
    },
  };

  /**
   * Active mode only — the `id` of the currently-highlighted item. Tracked here
   * rather than read back off the DOM so a re-render that drops the element can be
   * reconciled against the live item set.
   */
  #activeId: string | null = null;

  /**
   * Active mode only — the set of item `id`s this modifier minted, so cleanup
   * removes only its own and never strips an author-supplied id.
   */
  #mintedIds = new Set<string>();

  /** The callback already given the stable API, retained to avoid render-time churn. */
  #registeredApiCallback?: (api: DRovingFocusApi | null) => void;

  /**
   * Routes a keydown to the cursor. Only the keys this group owns are consumed; everything else
   * — including any chorded key, and the page keys when there is no logical row count — is left
   * un-prevented so the surrounding UI can act on it.
   *
   * @param event - The keydown from the container (focus mode) or the controller (active mode).
   */
  #handleKeydown = (event: KeyboardEvent): void => {
    // In focus mode the listener sits on the items' container, so a keydown can
    // bubble up from an editable descendant (a text field embedded inside an
    // item). Let that surface keep its own caret and selection keys — including
    // Home/End — rather than hijacking them for navigation.
    if (this.#mode === "focus" && this.#isEditableTarget(event.target)) {
      return;
    }

    // Active mode keeps focus on the controller. Vertical navigation and paging
    // belong to the listbox; Home/End do too for a non-editable controller, while
    // an editable controller keeps them for its caret.
    if (
      this.#mode === "active" &&
      event.key !== "ArrowDown" &&
      event.key !== "ArrowUp" &&
      event.key !== "Enter" &&
      event.key !== "PageUp" &&
      event.key !== "PageDown" &&
      !(
        (event.key === "Home" || event.key === "End") &&
        !this.#isEditableController()
      )
    ) {
      return;
    }

    // A chorded key belongs to whoever owns the chord — Cmd/Ctrl+Enter is a submit, Alt+Arrow
    // opens a combobox popup, Ctrl+Home is a document jump, and Shift+Arrow extends a text
    // selection in the controller. Claiming them as plain navigation both moves the cursor
    // unexpectedly and swallows the chord.
    if (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) {
      return;
    }

    const cells = this.#cells();
    if (!cells.length) {
      return;
    }

    const current = this.#currentIndex(cells);
    const columns = this.#columnCount();
    const last = cells.length - 1;
    const horizontal =
      this.#orientation === "horizontal" || this.#orientation === "grid";
    // Active mode is single-axis by construction — it leaves the horizontal arrows to the
    // controller's caret — so the vertical axis is always live there. Honouring
    // `orientation="horizontal"` would otherwise leave the group with no working arrow key at
    // all, and therefore no way to ever seed a cursor.
    const vertical =
      this.#mode === "active" ||
      this.#orientation === "vertical" ||
      this.#orientation === "grid";
    // A horizontal axis is physical, so its arrows follow the writing direction: in RTL the
    // visual "next" item is the one to the LEFT.
    const forwardKey = this.#isRtl() ? "ArrowLeft" : "ArrowRight";
    const backwardKey = this.#isRtl() ? "ArrowRight" : "ArrowLeft";

    let outcome: StepOutcome;
    switch (event.key) {
      case forwardKey:
      case backwardKey: {
        if (!horizontal) {
          return;
        }
        const delta = event.key === forwardKey ? 1 : -1;
        outcome = this.#step(current, delta, cells, columns);
        if (outcome.kind === "group-edge") {
          if (current >= 0 && this.#onExit) {
            event.preventDefault();
            this.#onExit(delta > 0 ? "forward" : "backward");
          }
          return;
        }
        break;
      }
      case "ArrowDown":
      case "ArrowUp": {
        if (!vertical) {
          return;
        }
        const direction = event.key === "ArrowDown" ? 1 : -1;
        // From no cursor, Down seeds the first item and Up the last.
        outcome =
          current < 0
            ? this.#step(-1, direction, cells, columns)
            : this.#stepRow(current, direction, cells, columns);
        if (outcome.kind === "group-edge") {
          if (current >= 0 && this.#onEdgeReach) {
            event.preventDefault();
            this.#onEdgeReach(direction > 0 ? "forward" : "backward");
          }
          return;
        }
        break;
      }
      case "Home":
        if (this.#logicalCount != null) {
          this.#jumpToLogicalIndex(0, "backward", event);
          return;
        }
        outcome = this.#edgeOutcome(cells, 0, 1, last);
        break;
      case "End":
        if (this.#logicalCount != null) {
          this.#jumpToLogicalIndex(this.#logicalCount - 1, "forward", event);
          return;
        }
        outcome = this.#edgeOutcome(cells, last, -1, last);
        break;
      case "PageUp":
      case "PageDown": {
        // Without a logical row count there is no page to move by. Treating the key as
        // Home/End would both lie about the distance and swallow it, so leave it alone and
        // let a scrollable container page natively.
        if (this.#logicalCount == null) {
          return;
        }
        const forward = event.key === "PageDown";
        // With no cursor there is no current row to page from; anchor on the mounted window
        // instead, or a PageDown computed from -1 pages BACKWARDS to the top of the data set.
        const anchor =
          current >= 0
            ? current
            : this.#scan(cells, forward ? 0 : last, forward ? 1 : -1, 0, last);
        const anchorLogical = this.#currentLogicalIndex(cells, anchor ?? 0);
        // A page is the mounted NAVIGABLE count, matching how `logicalCount` is defined. Paging
        // by the layout coordinate space instead would let a disabled placeholder lengthen the
        // jump and skip usable rows.
        // Floored at 1: a window of nothing but placeholder rows has no navigable items, and a
        // page of zero would target the row the cursor is already on and consume the key
        // forever.
        const page = Math.max(1, this.#items().length);
        this.#jumpToLogicalIndex(
          forward
            ? Math.min(anchorLogical + page, this.#logicalCount - 1)
            : Math.max(anchorLogical - page, 0),
          forward ? "forward" : "backward",
          event
        );
        return;
      }
      case "Enter":
      case " ":
        // In focus mode, only when the item ITSELF holds the key: `#currentIndex` resolves by
        // containment, so an item's own nested control would otherwise have its Enter stolen and
        // its native activation suppressed. Active mode is exempt by construction — DOM focus
        // stays on the controller there, so the target is never the item.
        //
        // The navigability check is not redundant: the cursor addresses the layout coordinate
        // space, which deliberately RETAINS disabled and hidden cells so the grid arithmetic
        // stays true. A row that becomes `aria-disabled` while holding the cursor keeps DOM
        // focus, so without this Enter would still activate it.
        if (
          current >= 0 &&
          this.#onActivate &&
          this.#isNavigable(cells[current]) &&
          (this.#mode === "active" || event.target === cells[current])
        ) {
          event.preventDefault();
          this.#onActivate(cells[current], event);
        }
        return;
      default:
        return;
    }

    if (outcome.kind === "move") {
      event.preventDefault();
      this.#setActive(cells[outcome.index]);
      return;
    }
    // A row edge stops the cursor and consumes the key, but reports nothing: the group has not
    // been left. A group edge with no callback falls through un-prevented so a surrounding
    // handler (a search field above the grid) can act on it.
    if (outcome.kind === "row-edge") {
      event.preventDefault();
    }
  };

  /**
   * Active mode only — moves the cursor onto the item a pointer press landed on, so the keyboard
   * continues from where the reader last acted rather than from wherever a re-seed would put it.
   * Ignores a press that missed an item (padding, a group header, a scrollbar) and one on an item
   * the keyboard would refuse to land on.
   *
   * @param event - The `mousedown` that landed on the container.
   */
  #handlePointerDown = (event: MouseEvent): void => {
    if (this.#mode !== "active" || !this.#itemSelector) {
      return;
    }
    // Only a primary press moves the cursor. A right- or middle-click opens a context menu or
    // pastes; moving the highlight under either reads as a selection the reader did not make.
    // `defaultPrevented` is deliberately NOT consulted: preventing default on `mousedown` is how
    // a combobox keeps focus on its input, so it marks an ordinary selection, not a claimed press.
    if (event.button !== 0) {
      return;
    }
    const target = (event.target as HTMLElement | null)?.closest<HTMLElement>(
      this.#itemSelector
    );
    // `closest` walks past the container, so a matching ANCESTOR would otherwise be given a
    // minted id and an `activeClass` that nothing scoped to this group could ever clean up.
    if (!target || !this.#element?.contains(target)) {
      return;
    }
    if (!this.#isNavigable(target)) {
      return;
    }
    this.#setActive(target, true);
  };

  constructor(owner: Owner, args: ArgsFor<DRovingFocusSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  /**
   * Reads the named args, (re)binds the keydown listener to the right element, and
   * seeds the cursor. Re-runs whenever a tracked arg changes — passing
   * `itemsKey=this.query` is how a filtering consumer asks the modifier to
   * re-reconcile the cursor against a freshly-rendered item set.
   */
  modify(element: HTMLElement, _positional: [], named: DRovingFocusArgs): void {
    this.#element = element;
    const previousMode = this.#mode;
    const previousActiveClass = this.#activeClass;
    const previousItemSelector = this.#itemSelector;
    const nextMode = named.selectionMode ?? "focus";

    // Everything the previous configuration wrote has to be swept BEFORE the new arguments are
    // adopted, because every sweep resolves items through the CURRENT `itemSelector` and class.
    // Adopting them first would aim the cleanup at the new item set and strand the old one.
    if (
      previousItemSelector !== named.itemSelector ||
      previousMode !== nextMode ||
      (previousActiveClass &&
        previousActiveClass !== (named.activeClass ?? null))
    ) {
      if (previousActiveClass) {
        this.#clearActiveClass(previousActiveClass);
      }
      if (
        previousItemSelector !== named.itemSelector ||
        previousMode !== nextMode
      ) {
        this.#exitEnteredModes();
        this.#disarmPendingSeed();
      }
    }

    this.#mode = nextMode;
    this.#orientation = named.orientation ?? "grid";
    this.#itemSelector = named.itemSelector;
    this.#columnsOverride = named.columns ?? null;
    this.#onActivate = named.onActivate;
    this.#onActiveChange = named.onActiveChange;
    this.#onExit = named.onExit;
    this.#onEdgeReach = named.onEdgeReach;
    this.#logicalCount = named.logicalCount;
    this.#onJump = named.onJump;
    this.#wrap = named.wrap ?? false;
    this.#tabStop = named.tabStop ?? true;
    this.#activeClass = named.activeClass ?? null;
    this.#autoActivateFirst = named.autoActivateFirst ?? false;
    this.#autoActivateSelected = named.autoActivateSelected ?? false;
    this.#activationRemovesSelected = named.activationRemovesSelected ?? false;
    // The read itself is the whole point: consuming the tag is what makes a changed
    // `itemsKey` re-run `modify()` and reconcile the cursor. The value is never needed,
    // so it is discarded rather than stored.
    void named.itemsKey;
    // Never on the first run: the sentinel guarantees a difference there, and treating that as a
    // reset would discard an author-supplied `tabindex="0"` before the group has done anything.
    const resetKeyChanged = this.#hasRun && named.resetKey !== this.#resetKey;
    this.#resetKey = named.resetKey;
    this.#hasRun = true;

    const listenElement =
      this.#mode === "active"
        ? this.#resolveController(named.controllerElement)
        : element;

    // Rebind only when the listener target changes (the controller element can be
    // swapped, or arrive late once its own `didInsert` has run).
    if (this.#listenElement !== listenElement) {
      this.#listenElement?.removeEventListener("keydown", this.#handleKeydown);
      // The outgoing controller must not keep pointing at an option it no longer controls.
      this.#listenElement?.removeAttribute("aria-activedescendant");
      this.#listenElement = listenElement ?? null;
      this.#listenElement?.addEventListener("keydown", this.#handleKeydown);
    }

    // The cursor follows a pointer press onto the item it lands on. Without this, activating an
    // item by pointer rebuilds the list, and the reconcile below finds no cursor to preserve and
    // seeds one at the top — marking a row the reader never touched, and pointing
    // `aria-activedescendant` at it. Bound to the container (items come and go), and on
    // `mousedown` so the cursor is in place before any consumer click handler rebuilds them.
    if (this.#pointerElement !== element) {
      this.#pointerElement?.removeEventListener(
        "mousedown",
        this.#handlePointerDown
      );
      this.#pointerElement = element;
      element.addEventListener("mousedown", this.#handlePointerDown);
    }

    // Recorded before seeding, since seeding is the act that writes to the DOM.
    this.#enteredModes.add(this.#mode);
    if (this.#mode === "active") {
      this.#reconcileActive(resetKeyChanged);
    } else {
      this.#seedTabStop(resetKeyChanged);
    }

    // Registered last, so a consumer that drives the cursor from inside the callback acts on a
    // bound listener and a seeded group rather than having its work undone by the seed below.
    if (this.#registeredApiCallback !== named.onRegisterApi) {
      // Tell the superseded holder its registration has ended. The handle it already has stays
      // functional while the modifier lives — there is one shared API object, and only teardown
      // makes it inert — so this is a notification, not a revocation.
      this.#registeredApiCallback?.(null);
      this.#registeredApiCallback = named.onRegisterApi;
      named.onRegisterApi?.(this.#api);
    }
  }

  /**
   * Resolves Home/End to the first or last navigable cell.
   *
   * @param cells - The coordinate space.
   * @param from - Where to start looking.
   * @param delta - Which way to walk when `from` is not navigable.
   * @param last - The highest index in `cells`.
   * @returns A move onto the end cell, or a group edge when nothing is navigable.
   */
  #edgeOutcome(
    cells: HTMLElement[],
    from: number,
    delta: number,
    last: number
  ): StepOutcome {
    const index = this.#scan(cells, from, delta, 0, last);
    return index == null ? { kind: "group-edge" } : { kind: "move", index };
  }

  /**
   * Whether the group is laid out right-to-left, which inverts the horizontal arrows.
   *
   * @returns `true` when the container resolves to a right-to-left writing direction.
   */
  #isRtl(): boolean {
    return this.#element
      ? getComputedStyle(this.#element).direction === "rtl"
      : false;
  }

  /**
   * Resolves the controller element from an `Element` or a CSS selector (matched
   * against the document).
   */
  #resolveController(
    controllerElement: Element | string | null | undefined
  ): HTMLElement | null {
    if (controllerElement instanceof HTMLElement) {
      return controllerElement;
    }
    if (typeof controllerElement === "string") {
      // Scoped to the document because the controller is deliberately OUTSIDE the group it
      // drives. A selector shared by several instances of the same widget therefore resolves to
      // the first match for all of them; pass the element itself when more than one can exist.
      return document.querySelector<HTMLElement>(controllerElement);
    }
    // `null`/`undefined` is a legitimate transient: the controller may not have rendered yet, and
    // a later `modify()` picks it up.
    return null;
  }

  /**
   * The live, navigable items in DOM order — the cursor's legal landing places. Re-queried on
   * every read (never cached) so a consumer that re-renders its list between keystrokes never
   * navigates a stale NodeList.
   *
   * @returns Every item the cursor may rest on.
   */
  #items(): HTMLElement[] {
    return this.#allItems().filter((el) => this.#isNavigable(el));
  }

  /**
   * The items that occupy a layout position, in DOM order. This is the coordinate space row and
   * column arithmetic must use: a row that is merely disabled or `visibility: hidden` still fills
   * its grid cell, so counting only the navigable items would shift every subsequent cell and make
   * a vertical step land a column adrift. `display: none` rows are excluded because the grid
   * genuinely reflows around them.
   *
   * @returns Every item that takes up space, navigable or not.
   */
  #cells(): HTMLElement[] {
    return this.#allItems().filter((el) => this.#occupiesLayout(el));
  }

  /**
   * Every item matching the selector, whatever its state. The highlight bookkeeping reaches for
   * this rather than `#items()` because a row can leave the navigable set *while it holds the
   * highlight* (e.g. it becomes `aria-disabled` on a runtime state change), and its stale
   * `activeClass` must still be cleared even though navigation no longer visits it.
   *
   * @returns Every item matching `itemSelector`.
   */
  #allItems(): HTMLElement[] {
    if (!this.#itemSelector || !this.#element) {
      return [];
    }
    return Array.from(
      this.#element.querySelectorAll<HTMLElement>(this.#itemSelector)
    );
  }

  /**
   * Strips `activeClass` from every item, navigable or not, so a row disabled while active does
   * not keep the highlight.
   *
   * @param className - The class to strip; defaults to the currently configured one. Passing the
   * previous value is how a changed `activeClass` is swept off the row that still wears it.
   */
  #clearActiveClass(className: string | null = this.#activeClass): void {
    if (!className) {
      return;
    }
    for (const el of this.#allItems()) {
      el.classList.remove(className);
    }
  }

  #isEditableController(): boolean {
    return this.#isEditableTarget(this.#listenElement);
  }

  /**
   * Whether the event target is a text-editing surface whose own caret and
   * selection keys must take precedence over roving navigation — a native form
   * control (`INPUT`/`TEXTAREA`/`SELECT`) or any `contenteditable` host.
   */
  #isEditableTarget(target: EventTarget | null): boolean {
    if (!(target instanceof HTMLElement)) {
      return false;
    }
    const tag = target.tagName;
    return (
      tag === "INPUT" ||
      tag === "TEXTAREA" ||
      tag === "SELECT" ||
      target.isContentEditable
    );
  }

  /**
   * Whether an item takes up a layout position. `offsetParent` is null for `display: none`
   * (and for `position: fixed`); the client-rects check keeps a fixed-position item counted
   * while still rejecting a hidden one.
   *
   * @param el - The candidate item.
   * @returns `true` when the item occupies space, whether or not it can be navigated to.
   */
  #occupiesLayout(el: HTMLElement): boolean {
    return Boolean(el.offsetParent) || el.getClientRects().length > 0;
  }

  /**
   * Whether an item can be a navigation target — it occupies space, is not disabled, and is
   * not hidden.
   *
   * @param el - The candidate item.
   * @returns `true` when the cursor may rest on the item.
   */
  #isNavigable(el: HTMLElement): boolean {
    if (el.getAttribute("aria-disabled") === "true") {
      return false;
    }
    // `:disabled` rather than the `disabled` IDL property, so a control disabled through an
    // ancestor `fieldset` is rejected too — it cannot take focus either way.
    if (el.matches(":disabled")) {
      return false;
    }
    if (!this.#occupiesLayout(el)) {
      return false;
    }
    // `visibility: hidden` still participates in layout, so the checks above pass, yet the
    // element cannot take focus — a `focus()` on it is a no-op and would leave the cursor
    // stranded. Checked last because it is the only check that forces a style resolution.
    return getComputedStyle(el).visibility === "visible";
  }

  /**
   * The number of columns the cursor navigates by.
   *
   * Only a `"grid"` group in `"focus"` mode has a second axis, so both other cases resolve to
   * one column BEFORE `columns` is read: `columns` is a grid-only override, and honouring it
   * elsewhere makes a vertical step skip rows on an axis that has none. Active mode leaves the
   * horizontal arrows to its controller's caret, so its cursor can never reach a second column
   * — deriving one would strand every item outside the first.
   *
   * Otherwise derived from the resolved `grid-template-columns` track list
   * (e.g. `"96px 96px 96px"` → 3), which the browser resolves even for `repeat(auto-fill, …)`.
   * Falls back to a single column when the computed value is empty or `none`.
   *
   * @returns The column count, at least 1.
   */
  #columnCount(): number {
    if (this.#mode === "active" || this.#orientation !== "grid") {
      return 1;
    }
    if (typeof this.#columnsOverride === "function") {
      return this.#sanitizeColumns(this.#columnsOverride());
    }
    if (typeof this.#columnsOverride === "number") {
      return this.#sanitizeColumns(this.#columnsOverride);
    }
    if (!this.#element) {
      return 1;
    }
    const tracks = getComputedStyle(this.#element).gridTemplateColumns;
    if (!tracks || tracks === "none") {
      return 1;
    }
    // Named grid lines survive into the computed value (`[full-start] 300px [mid] 300px`) and
    // are not tracks; counting them reads a two-track grid as five columns. `subgrid` is not a
    // track either. (`none` cannot appear here — it can only ever be the whole value, handled
    // above.)
    const count = tracks
      .trim()
      .replace(/\[[^\]]*\]/g, " ")
      .split(/\s+/)
      .filter((token) => token && token !== "subgrid").length;
    return count >= 1 ? count : 1;
  }

  /**
   * Coerces a consumer-supplied column count into a usable positive integer. A measured
   * callback (`() => width / tileWidth`) can hand back a fraction, which would otherwise
   * produce a fractional index and dereference a hole in the item list.
   *
   * @param value - The raw override value.
   * @returns A whole column count of at least 1.
   */
  #sanitizeColumns(value: number): number {
    return Number.isFinite(value) ? Math.max(1, Math.floor(value)) : 1;
  }

  /**
   * The index of the current cursor position among `items`: where DOM focus is
   * (focus mode) or which item the controller's `aria-activedescendant` points at
   * (active mode), with a sensible fallback so a lost cursor lands on the tab stop.
   *
   * In focus mode the active element is matched by containment, not identity, so
   * focus resting on a focusable descendant of an item (e.g. an inline control
   * inside a row, or the trigger a closed menu just handed focus back to) still
   * resolves to that item.
   */
  #currentIndex(cells: HTMLElement[]): number {
    if (this.#mode === "active") {
      // May be -1 — "no active option yet". Callers treat a negative index as no
      // highlight: Arrow seeds the first/last item, Enter falls through so the
      // consumer can submit or create.
      return cells.findIndex((el) => el.id === this.#activeId);
    }
    const active = document.activeElement;
    // Innermost first: `querySelectorAll` yields tree order, so an item that CONTAINS another
    // matching item precedes it. Scanning forwards would resolve a nested row to its ancestor
    // and navigate from the wrong position.
    for (let i = cells.length - 1; i >= 0; i--) {
      if (cells[i] === active || cells[i].contains(active)) {
        return i;
      }
    }
    // Nothing is focused, so fall back to the established tab stop. The ATTRIBUTE, not the
    // `tabIndex` property, which reports 0 for any natively-focusable element and would invent
    // a cursor on an item the modifier never stamped.
    return cells.findIndex((el) => el.getAttribute("tabindex") === "0");
  }

  /**
   * The absolute logical row the cursor sits on, for the jump keys.
   *
   * @param cells - The current coordinate space.
   * @param current - The cursor's position within it, or a negative value for no cursor.
   * @returns The stamped logical index, or the positional one when no item carries a stamp.
   */
  #currentLogicalIndex(cells: HTMLElement[], current: number): number {
    const element = cells[current];
    const logical = element?.dataset.logicalIndex ?? element?.dataset.index;
    if (logical === undefined) {
      return current;
    }
    const parsed = Number(logical);
    return Number.isFinite(parsed) ? parsed : current;
  }

  /**
   * Services a logical jump key: lands locally when the target row is mounted, otherwise hands
   * it to `onJump`. The key is only consumed when one of those actually happens — a consumer
   * that sets `logicalCount` without `onJump` cannot service an off-window target, and
   * swallowing the key there would turn Home/End into dead keys.
   *
   * @param target - The absolute logical row to move to.
   * @param direction - Which way the jump travels, for `onJump`.
   * @param event - The key to consume once the jump is serviced.
   */
  #jumpToLogicalIndex(
    target: number,
    direction: "forward" | "backward",
    event: KeyboardEvent
  ): void {
    if (this.#api.focusLogicalIndex(target)) {
      event.preventDefault();
      return;
    }
    if (this.#onJump) {
      event.preventDefault();
      this.#onJump(target, direction);
    }
  }

  /**
   * One step along the row axis, skipping cells the cursor may not land on.
   *
   * Under `orientation="grid"` with more than one column a row is closed on both sides: per
   * the WAI-ARIA grid pattern, Right on a row's last cell does not move to the next row's
   * first cell. That is reported as `"row-edge"` rather than `"group-edge"` so it stays
   * silent — `onExit` means "leaving the group", and firing it from an interior row would
   * drag a consumer's focus away mid-traversal.
   *
   * Keyed strictly on the orientation, never on geometry: a `"horizontal"` group whose items
   * visually wrap onto several lines is still one logical row.
   *
   * @param index - The cursor's current position, or a negative value for no cursor.
   * @param delta - `1` to move forward through DOM order, `-1` to move back.
   * @param cells - The coordinate space to move through.
   * @param columns - The current column count.
   * @returns Where the cursor lands, or which kind of edge blocked it.
   */
  #step(
    index: number,
    delta: 1 | -1,
    cells: HTMLElement[],
    columns: number
  ): StepOutcome {
    const last = cells.length - 1;
    // No cursor yet: a first horizontal Arrow seeds an end, mirroring the vertical keys. Handled
    // up front so the row arithmetic below never sees a negative index.
    if (index < 0) {
      const seed = this.#scan(cells, delta > 0 ? 0 : last, delta, 0, last);
      return seed == null
        ? { kind: "group-edge" }
        : { kind: "move", index: seed };
    }

    const rowBound = this.#orientation === "grid" && columns > 1;
    const rowStart = rowBound ? index - (index % columns) : 0;
    // `min` closes a ragged last row on its real end rather than a phantom column.
    const rowEnd = rowBound ? Math.min(rowStart + columns - 1, last) : last;

    const next = this.#scan(cells, index + delta, delta, rowStart, rowEnd);
    if (next != null) {
      return { kind: "move", index: next };
    }
    if (this.#wrap) {
      const wrapped = this.#scan(
        cells,
        delta > 0 ? rowStart : rowEnd,
        delta,
        rowStart,
        rowEnd
      );
      if (wrapped != null) {
        // Landing back on the cursor is not a move — reporting one would fire `onActiveChange`
        // for a cursor that never went anywhere — but it is still a wrap, so it must not fall
        // through to the edge branch either: `wrap` promises to suppress `onExit`.
        return wrapped === index
          ? { kind: "row-edge" }
          : { kind: "move", index: wrapped };
      }
    }
    // A row edge that is also the end of the whole group is a group edge — which is every
    // blocked step in a non-grid group, so their behaviour is unchanged.
    const atGroupEdge = delta > 0 ? rowEnd === last : rowStart === 0;
    return { kind: atGroupEdge ? "group-edge" : "row-edge" };
  }

  /**
   * One step along the column axis (± one row), skipping cells the cursor may not land on.
   *
   * @param index - The cursor's current position; never negative (the caller seeds an end first).
   * @param direction - `1` for down, `-1` for up.
   * @param cells - The coordinate space to move through.
   * @param columns - The current column count.
   * @returns Where the cursor lands, or which kind of edge blocked it.
   */
  #stepRow(
    index: number,
    direction: 1 | -1,
    cells: HTMLElement[],
    columns: number
  ): StepOutcome {
    const last = cells.length - 1;
    const next = this.#scan(
      cells,
      index + direction * columns,
      direction * columns,
      0,
      last
    );
    if (next != null) {
      return { kind: "move", index: next };
    }
    // Moving down out of a full row onto a SHORTER last row lands on the final cell rather than
    // dead-ending. This is strictly about a column that does not exist: if the cursor's column
    // is present in the last row but simply not navigable, the cursor has genuinely reached the
    // bottom of its column and must report an edge — falling back here would send it diagonally
    // into a different column.
    const lastRowStart = last - (last % columns);
    if (
      direction > 0 &&
      Math.floor(index / columns) < Math.floor(last / columns) &&
      // The cursor's column must have run OUT, not merely be blocked. `#scan` returns null both
      // when there is no cell below and when the cells below are non-navigable; only the first is
      // a ragged row. Given the cursor is above the last row, this can only be true when the row
      // directly below is the last one and it is too short to hold the cursor's column.
      index + columns > last
    ) {
      // Bounded to the last row, so the fallback can only ever land on that row's trailing cells
      // and never reaches back up into a row the cursor has already passed.
      const trailing = this.#scan(cells, last, -1, lastRowStart, last);
      if (trailing != null) {
        return { kind: "move", index: trailing };
      }
    }
    if (this.#wrap) {
      // Column-aware: wrapping goes to the far end of the SAME column, not to a flat modulo of
      // the list, which would land a column adrift in any multi-column grid.
      const column = index % columns;
      const from =
        direction > 0
          ? column
          : column + Math.floor((last - column) / columns) * columns;
      const wrapped = this.#scan(cells, from, direction * columns, 0, last);
      if (wrapped != null) {
        // As in `#step`: a wrap onto the cursor itself is not a move, but it is still a wrap, so
        // it must not be reported as an edge that `wrap` promised to suppress.
        return wrapped === index
          ? { kind: "row-edge" }
          : { kind: "move", index: wrapped };
      }
    }
    return { kind: "group-edge" };
  }

  /**
   * Walks `cells` by `delta` looking for the first navigable one.
   *
   * @param cells - The coordinate space to walk.
   * @param from - Where to start looking (inclusive).
   * @param delta - The stride, positive or negative.
   * @param min - Lowest index the walk may visit.
   * @param max - Highest index the walk may visit.
   * @returns The index of the first navigable cell, or `null` when the walk runs out.
   */
  #scan(
    cells: HTMLElement[],
    from: number,
    delta: number,
    min: number,
    max: number
  ): number | null {
    for (let i = from; i >= min && i <= max; i += delta) {
      if (this.#isNavigable(cells[i])) {
        return i;
      }
    }
    return null;
  }

  /**
   * Moves the cursor to `target`: in focus mode, updates the items' tabindex values
   * and moves DOM focus; in active mode, repoints `aria-activedescendant`, moves
   * `activeClass`, and scrolls the item into view without moving focus.
   *
   * @param target - The item to move the cursor onto.
   * @param pointer - Whether a pointer press placed it, forwarded to `onActiveChange` so a
   * consumer can distinguish "the cursor moved" from "show the cursor".
   */
  #setActive(target: HTMLElement, pointer = false): void {
    if (this.#mode === "active") {
      // Sweep all items, not just the navigable ones: the previously-active row may have just
      // been disabled, which drops it from that set while it still carries the class.
      this.#clearActiveClass();
      const id = this.#ensureId(target);
      this.#activeId = id;
      if (this.#activeClass) {
        target.classList.add(this.#activeClass);
      }
      this.#listenElement?.setAttribute("aria-activedescendant", id);
      this.#scrollActiveIntoView(target);
    } else {
      // Every matching item, not just the navigable ones: a row that became `aria-disabled`
      // while holding the tab stop has left the navigable set, and skipping it would leave its
      // `tabindex="0"` in place as a second, unreachable tab stop.
      for (const el of this.#allItems()) {
        el.tabIndex = this.#tabStop && el === target ? 0 : -1;
      }
      target.focus();
    }
    this.#onActiveChange?.(target, { pointer });
  }

  /**
   * Scrolls the active item into view within its nearest scrollable ancestor ONLY — never the
   * page. `scrollIntoView` scrolls every scrollable ancestor including the window, and an overlay
   * rendered into a detached container before its anchored position is applied still reports a
   * page position at the top of the document, so scrolling the window would jump the whole page.
   * Adjusting only the container's `scrollTop` keeps a long list navigable without ever moving the
   * page; when the only scroller up the tree is the document, it does nothing.
   *
   * @param target - The item to bring into view.
   */
  #scrollActiveIntoView(target: HTMLElement): void {
    const container = this.#scrollableAncestor(target);
    if (!container) {
      return;
    }
    const itemRect = target.getBoundingClientRect();
    const containerRect = container.getBoundingClientRect();
    if (itemRect.top < containerRect.top) {
      container.scrollTop -= containerRect.top - itemRect.top;
    } else if (itemRect.bottom > containerRect.bottom) {
      container.scrollTop += itemRect.bottom - containerRect.bottom;
    }
  }

  /**
   * The nearest scrollable ancestor of `element`, stopping before the document scroller so the
   * page is never a scroll target. Returns `null` when the only scroller up the tree is the
   * document/body.
   */
  #scrollableAncestor(element: HTMLElement): HTMLElement | null {
    let node: HTMLElement | null = element.parentElement;
    while (
      node &&
      node !== document.body &&
      node !== document.documentElement
    ) {
      const overflowY = getComputedStyle(node).overflowY;
      // Deliberately not gated on the container currently overflowing: the intended scroller is
      // often measured before it has a height (an overlay is positioned a frame after it mounts),
      // and skipping it there would walk on and scroll something unrelated instead. A
      // non-overflowing container simply absorbs the adjustment as a no-op.
      if (overflowY === "auto" || overflowY === "scroll") {
        return node;
      }
      // Deliberately not stopped at the group's own container: a windowed list puts the scroller
      // AROUND the element the modifier is attached to, so stopping there would find nothing and
      // never scroll a long list at all.
      node = node.parentElement;
    }
    return null;
  }

  /**
   * Focus mode — stamps every item with an explicit tabindex. When `tabStop` is enabled, prefers
   * an already-established tab stop, else an `[aria-selected="true"]`/`[aria-current]` item, else
   * the first item. Does NOT move focus, so re-seeding after a re-render (or while the user is
   * typing in a separate search field) never yanks focus.
   *
   * @param reseed - Ignore an established tab stop and pick afresh, because the items now answer
   * a different question (`resetKey`). Without this a surviving row keeps the tab stop buried
   * mid-list after a re-filter.
   */
  #seedTabStop(reseed = false): void {
    const items = this.#items();
    // The ATTRIBUTE, not the `tabIndex` property: every natively-focusable element reports 0
    // without carrying the attribute, so reading the property would match the first button here
    // and make the `aria-selected`/`aria-current` preferences below unreachable.
    const established = reseed
      ? undefined
      : items.find((el) => el.getAttribute("tabindex") === "0");
    const preferred =
      established ??
      items.find((el) => el.getAttribute("aria-selected") === "true") ??
      items.find((el) => el.hasAttribute("aria-current")) ??
      items[0];
    // Then demote every matching item, navigable or not: a row disabled while it held the tab
    // stop has left the navigable set, and seeding only across that set would leave its
    // `tabindex="0"` in place as a second, unreachable tab stop.
    for (const el of this.#allItems()) {
      el.tabIndex = -1;
    }
    if (this.#tabStop && preferred) {
      preferred.tabIndex = 0;
    }
  }

  /**
   * Active mode — reconciles the highlight after the item set may have changed
   * (`itemsKey`). If the previously-active id is gone (or there was none), clears the
   * highlight so `aria-activedescendant` never points at a removed element; the next
   * Arrow keypress seeds a new active option.
   *
   * @param reseed - Treat the cursor as gone even if its row survived, because the items now
   * answer a different question (`resetKey`).
   */
  #reconcileActive(reseed = false): void {
    const items = this.#items();
    const stillPresent =
      !reseed &&
      this.#activeId != null &&
      items.some((el) => el.id === this.#activeId);
    if (!stillPresent) {
      // Seed the cursor when asked (combobox automatic-selection). The stale `#activeId` can't
      // match any current element, so `#setActive` finds no previous highlight to clear.
      // The user's own choice outranks the first row: reopening a list should point at what
      // they already picked, not at an unrelated option.
      const selected = this.#autoActivateSelected
        ? items.find((el) => el.getAttribute("aria-selected") === "true")
        : undefined;
      const seed = selected ?? this.#autoFirstSeed(items);
      if (seed) {
        this.#disarmPendingSeed();
        this.#setActive(seed);
        return;
      }
      // A seed that found no items at all has not been answered yet — a windowed list installs
      // this modifier on a container the virtualizer has not filled, so the rows land a frame
      // later and no key changes when they do. Wait for them once, rather than presenting a list
      // whose cursor the reader has to create with a wasted arrow press.
      //
      // Deliberately not a re-seed on every item change: a windowed list republishes its rows on
      // every scroll, and re-seeding there would throw a reader who has arrowed away back to the
      // top. An item set that exists and yielded no seed is a decision, not an absence.
      // Keyed on the NAVIGABLE items, matching what the observer's own callback checks. A window
      // of placeholder rows has none, and replacing those rows with real ones is a childList
      // mutation, so the watch fires and the seed lands. The callback stays armed until it finds
      // something navigable, so arming on the rendered count instead would simply never seed
      // such a window at all.
      if (!items.length) {
        this.#armPendingSeed();
      }
      this.#activeId = null;
      this.#listenElement?.removeAttribute("aria-activedescendant");
      // Sweep all items: the row that lost the highlight may have left the navigable set
      // (disabled) in the same change that cleared the cursor.
      this.#clearActiveClass();
      // Notify the consumer too, so a template-driven highlight (a tracked active key rendered as
      // a class) clears alongside the modifier's own `activeClass` and `aria-activedescendant`.
      this.#onActiveChange?.(null);
      return;
    }
    const target = items.find((el) => el.id === this.#activeId);
    if (this.#activeClass) {
      this.#clearActiveClass();
      target?.classList.add(this.#activeClass);
    }
    this.#listenElement?.setAttribute("aria-activedescendant", this.#activeId!);
  }

  /**
   * Watches the container for the arrival of its first items, then seeds the cursor once and
   * stops. One-shot by construction: the observer disconnects before reconciling, so a container
   * that keeps churning rows is never re-seeded.
   */
  #armPendingSeed(): void {
    if (this.#pendingSeed || !this.#element) {
      return;
    }
    if (!this.#autoActivateFirst && !this.#autoActivateSelected) {
      return;
    }

    this.#pendingSeed = new MutationObserver(() => {
      // Re-check the conditions that armed it: an arg change between arming and firing can have
      // left active mode entirely, and seeding from here would then take real DOM focus with no
      // keypress behind it.
      if (
        this.#mode !== "active" ||
        (!this.#autoActivateFirst && !this.#autoActivateSelected)
      ) {
        this.#disarmPendingSeed();
        return;
      }
      if (!this.#items().length) {
        return;
      }
      this.#disarmPendingSeed();
      this.#reconcileActive();
    });
    this.#pendingSeed.observe(this.#element, {
      childList: true,
      subtree: true,
    });
  }

  #disarmPendingSeed(): void {
    this.#pendingSeed?.disconnect();
    this.#pendingSeed = null;
  }

  /**
   * The first item the cursor may safely start on, honouring `activationRemovesSelected`.
   *
   * Returns nothing when `autoActivateFirst` is off (the default), and — when
   * `activationRemovesSelected` is set — when every *mounted navigable* item is selected, which a
   * windowed list reaches while unselected rows still exist offscreen. The cursor then stays empty
   * until an Arrow moves it, rather than falling back to a row whose activation would discard a
   * value.
   *
   * @param items - The navigable items to choose from.
   * @returns The item to seed the cursor on, or `undefined` to leave it empty.
   */
  #autoFirstSeed(items: HTMLElement[]): HTMLElement | undefined {
    if (!this.#autoActivateFirst) {
      return undefined;
    }
    if (!this.#activationRemovesSelected) {
      return items[0];
    }
    return items.find((el) => el.getAttribute("aria-selected") !== "true");
  }

  /**
   * Returns an item's `id`, minting a stable one (tracked for cleanup) when the
   * author hasn't supplied it — `aria-activedescendant` references items by id.
   *
   * @param el - The item that needs an id.
   * @returns The item's existing id, or the newly minted one.
   */
  #ensureId(el: HTMLElement): string {
    if (!el.id) {
      const id = `${guidFor(this)}-${this.#mintCounter++}`;
      el.id = id;
      this.#mintedIds.add(id);
    }
    return el.id;
  }

  /**
   * Undoes everything every mode this instance actually ran in wrote to the DOM. Branching on
   * whichever mode happens to be current would strand the other one's artifacts, while exiting
   * modes that never ran would remove attributes the author owns.
   */
  #exitEnteredModes(): void {
    for (const mode of this.#enteredModes) {
      this.#exitMode(mode);
    }
    this.#enteredModes.clear();
  }

  /**
   * Undoes everything one mode wrote to the DOM.
   *
   * @param mode - The mode being left.
   */
  #exitMode(mode: SelectionMode): void {
    if (mode === "active") {
      this.#listenElement?.removeAttribute("aria-activedescendant");
      this.#activeId = null;
      this.#clearActiveClass();
      for (const el of this.#allItems()) {
        if (this.#mintedIds.has(el.id)) {
          el.removeAttribute("id");
        }
      }
      this.#mintedIds.clear();
      return;
    }
    // Focus mode owns only the tabindex values it stamped.
    for (const el of this.#allItems()) {
      el.removeAttribute("tabindex");
    }
  }

  /**
   * Releases every listener, observer and timer, and gives back everything either mode wrote to
   * the DOM. Registered as the destructor, so it also revokes the consumer's API handle.
   */
  #cleanup(): void {
    this.#disarmPendingSeed();
    if (this.#reannounceTimer) {
      cancel(this.#reannounceTimer);
      this.#reannounceTimer = undefined;
    }
    this.#listenElement?.removeEventListener("keydown", this.#handleKeydown);
    this.#pointerElement?.removeEventListener(
      "mousedown",
      this.#handlePointerDown
    );
    // Every mode this instance ran in, not just the current one: a modifier that spent part of
    // its life in active mode and ended in focus mode still has that mode's ids and attribute to
    // give back.
    this.#exitEnteredModes();
    this.#listenElement = null;
    this.#pointerElement = null;
    this.#element = null;
    this.#registeredApiCallback?.(null);
    this.#registeredApiCallback = undefined;
  }
}
