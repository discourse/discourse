import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
import { cancel, next as nextRunloop } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";

type SelectionMode = "focus" | "active";
type Orientation = "grid" | "horizontal" | "vertical";

/**
 * Controls for moving the cursor to a live item in the roving-focus group. Each
 * returns whether it landed on an item — `false` when the group is currently empty
 * (e.g. a re-render dropped every item), so the caller can fall back.
 */
export interface DRovingFocusApi {
  focusFirst(): boolean;
  focusLast(): boolean;
  focusIndex(index: number): boolean;
  /**
   * Move the cursor to the item whose `data-index` is the given ABSOLUTE logical
   * index — the addressing a windowed list needs, where the mounted items are a
   * slice of a much larger set and their NodeList position is not their true
   * index. Returns `false` when that logical index is not currently mounted (the
   * caller must scroll it into view first). When no item carries `data-index`
   * (a non-windowed group) it falls back to positional addressing, like
   * {@link focusIndex}.
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
  /** Navigation axes; `"grid"` (default) allows both, `"horizontal"`/`"vertical"` one. */
  orientation?: Orientation;
  /** CSS selector matching the navigable items within the container. */
  itemSelector?: string;
  /** Column count override for non-grid layouts; a number or a `() => number`. */
  columns?: number | (() => number) | null;
  /** Called when an item is activated (Enter / Space). */
  onActivate?: (item: HTMLElement, event: KeyboardEvent) => void;
  /** Called whenever the cursor moves to a new item, or `null` when the highlight is cleared. */
  onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;
  /** Called at a horizontal edge when `wrap` is false; wrapping suppresses it. */
  onExit?: (direction: "forward" | "backward") => void;
  /**
   * The vertical counterpart to {@link onExit}: called when ArrowDown from the
   * last item, or ArrowUp from the first, would move past the edge with `wrap`
   * false and a cursor present. `"forward"` is down, `"backward"` is up. A
   * windowed list uses it to scroll or fetch the next rows before the cursor
   * reaches the true end.
   */
  onEdgeReach?: (direction: "forward" | "backward") => void;
  /**
   * The total number of navigable logical rows. When omitted, jump keys use the
   * mounted items' positions and {@link onJump} is never called.
   */
  logicalCount?: number;
  /**
   * Called when a logical jump target is outside the currently-mounted item
   * window, so the consumer can mount and focus that row.
   */
  onJump?: (target: number, direction: "forward" | "backward") => void;
  /** Registers stable controls for moving the cursor, and receives `null` on teardown. */
  onRegisterApi?: (api: DRovingFocusApi | null) => void;
  /** Whether navigation wraps at the ends (default `false` = clamp). */
  wrap?: boolean;
  /** Focus mode: whether one item is reachable with Tab (default `true`). */
  tabStop?: boolean;
  /** Class toggled on the active item in `"active"` mode. */
  activeClass?: string | null;
  /** A reactive key (e.g. the filter string) that re-reconciles the cursor when it changes. */
  itemsKey?: unknown;
  /**
   * A reactive key identifying the *question* the items answer. Reconciling normally keeps the
   * cursor on the active item whenever it survives the change, which is right when rows are
   * appended or revised but wrong when the list becomes a different result set: a row that
   * happens to match both queries would hold the cursor deep in the new list. Change this and
   * the cursor re-seeds from the top instead of tracking the survivor.
   *
   * Key it on the query the *rendered* items answer, not the one being typed — a list that
   * keeps its old rows visible during an async reload would otherwise re-seed against them.
   */
  resetKey?: unknown;
  /** Active mode: the element that keeps focus (a text input), by `Element` or selector. */
  controllerElement?: Element | string | null;
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
   * The consumer owns `aria-selected`; this only reads it, mirroring what `#seedTabStop` already
   * does in focus mode. Default `false`.
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
 * - `"focus"` (the default) — a roving tabindex. By default, exactly one item is
 *   reachable with Tab (`tabindex="0"`); the rest are `tabindex="-1"`. With
 *   `tabStop=false`, every item remains at `tabindex="-1"`. Arrow keys move real DOM
 *   focus between items and update tabindex along with it. Use this when the active
 *   item should itself hold focus (a tile grid, a toolbar).
 * - `"active"` — `aria-activedescendant`. DOM focus stays on a separate controller
 *   element (typically a text input); arrow keys move a *virtual* highlight through
 *   the items by pointing the controller's `aria-activedescendant` at the active
 *   item and toggling `activeClass` on it. Use this for a combobox where the user
 *   must keep typing while navigating results.
 *
 * Navigation is always DOM order — the grid's column count is derived from the
 * resolved `grid-template-columns` at keydown time, never from element geometry
 * (`offsetTop`/`offsetLeft`), so a responsive grid that reflows is handled for free.
 *
 * The modifier is deliberately role-agnostic: the consumer supplies the container
 * and item roles (`role="listbox"`/`"grid"` + `role="option"`, and, for active mode,
 * `role="combobox"` + `aria-controls` on the controller). The modifier owns only the
 * keyboard cursor — `tabindex` (focus mode) or `aria-activedescendant` + `activeClass`
 * (active mode). It never touches `aria-selected`, which expresses a *chosen value*
 * (a separate concept the consumer owns).
 */
export default class DRovingFocusModifier extends Modifier<DRovingFocusSignature> {
  /** The element the modifier is attached to (the items' container). */
  element: HTMLElement | null = null;

  orientation: Orientation = "grid";
  itemSelector?: string;
  columnsOverride: number | (() => number) | null = null;
  onActivate?: (item: HTMLElement, event: KeyboardEvent) => void;
  onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;
  onExit?: (direction: "forward" | "backward") => void;
  onEdgeReach?: (direction: "forward" | "backward") => void;
  logicalCount?: number;
  onJump?: (target: number, direction: "forward" | "backward") => void;
  wrap = false;
  tabStop = true;
  activeClass: string | null = null;
  itemsKey: unknown;
  autoActivateFirst = false;
  autoActivateSelected = false;
  activationRemovesSelected = false;

  /** The element keydown is bound to: the container (focus) or controller (active). */
  #listenElement: HTMLElement | null = null;
  #pointerElement: HTMLElement | null = null;

  /** Armed only while a seed is owed to a container that had no items yet. */
  #pendingSeed: MutationObserver | null = null;

  /** Pending restore of a dropped `aria-activedescendant` — see `reannounceActive`. */
  #reannounceTimer?: ReturnType<typeof nextRunloop>;

  // The last `resetKey` seen. The sentinel is a fresh object so the first `modify()` always
  // counts as a change — harmless, since there is no cursor yet to preserve, and it keeps the
  // "unset" case from colliding with a consumer that legitimately passes `undefined`.
  #resetKey: unknown = Symbol("unset");

  #mode: SelectionMode = "focus";

  /** Stable controls registered with the consumer for moving focus into the group. */
  #api: DRovingFocusApi = {
    focusFirst: () => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      this.#setActive(items[0], items);
      return true;
    },
    focusLast: () => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      this.#setActive(items[items.length - 1], items);
      return true;
    },
    focusIndex: (index) => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      const last = items.length - 1;
      this.#setActive(items[Math.max(0, Math.min(index, last))], items);
      return true;
    },
    focusLogicalIndex: (index) => {
      const items = this.#items();
      if (!items.length) {
        return false;
      }
      // Prefer an explicit logical ordinal (`data-logical-index`) where a consumer stamps one,
      // so a windowed list with non-option rows can address options independently of the raw
      // virtualizer index; fall back to `data-index` for consumers that stamp neither.
      const match = items.find(
        (el) => (el.dataset.logicalIndex ?? el.dataset.index) === String(index)
      );
      if (match) {
        this.#setActive(match, items);
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
        return this.#api.focusIndex(index);
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
      this.#reannounceTimer = nextRunloop(() => {
        this.#reannounceTimer = undefined;
        // A real cursor move in the meantime has already pointed the attribute somewhere, and
        // restoring the old id would drag the reader back.
        if (this.#activeId === id && this.#items().some((el) => el.id === id)) {
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

  constructor(owner: Owner, args: ArgsFor<DRovingFocusSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  /**
   * Reads the named args, (re)binds the keydown listener to the right element, and
   * seeds the cursor. Re-runs whenever a tracked arg changes — passing
   * `itemsKey=this.query` is how a filtering consumer asks the modifier to
   * re-reconcile the cursor against a freshly-rendered item set.
   */
  modify(element: HTMLElement, _positional: [], named: DRovingFocusArgs): void {
    this.element = element;
    this.#mode = named.selectionMode ?? "focus";
    this.orientation = named.orientation ?? "grid";
    this.itemSelector = named.itemSelector;
    this.columnsOverride = named.columns ?? null;
    this.onActivate = named.onActivate;
    this.onActiveChange = named.onActiveChange;
    this.onExit = named.onExit;
    this.onEdgeReach = named.onEdgeReach;
    this.logicalCount = named.logicalCount;
    this.onJump = named.onJump;
    this.wrap = named.wrap ?? false;
    this.tabStop = named.tabStop ?? true;
    this.activeClass = named.activeClass ?? null;
    this.autoActivateFirst = named.autoActivateFirst ?? false;
    this.autoActivateSelected = named.autoActivateSelected ?? false;
    this.activationRemovesSelected = named.activationRemovesSelected ?? false;
    // Reading `itemsKey` here keeps `modify()` reactive to it; the value itself
    // isn't used beyond triggering a re-run + reconcile.
    this.itemsKey = named.itemsKey;
    const resetKeyChanged = named.resetKey !== this.#resetKey;
    this.#resetKey = named.resetKey;

    if (this.#registeredApiCallback !== named.onRegisterApi) {
      this.#registeredApiCallback = named.onRegisterApi;
      named.onRegisterApi?.(this.#api);
    }

    const listenElement =
      this.#mode === "active"
        ? this.#resolveController(named.controllerElement)
        : element;

    // Rebind only when the listener target changes (the controller element can be
    // swapped, or arrive late once its own `didInsert` has run).
    if (this.#listenElement !== listenElement) {
      this.#listenElement?.removeEventListener("keydown", this.handleKeydown);
      this.#listenElement = listenElement ?? null;
      this.#listenElement?.addEventListener("keydown", this.handleKeydown);
    }

    // The cursor follows a pointer press onto the item it lands on. Without this, activating an
    // item by pointer rebuilds the list, and the reconcile below finds no cursor to preserve and
    // seeds one at the top — marking a row the reader never touched, and pointing
    // `aria-activedescendant` at it. Bound to the container (items come and go), and on
    // `mousedown` so the cursor is in place before any consumer click handler rebuilds them.
    if (this.#pointerElement !== element) {
      this.#pointerElement?.removeEventListener(
        "mousedown",
        this.handlePointerDown
      );
      this.#pointerElement = element;
      element.addEventListener("mousedown", this.handlePointerDown);
    }

    if (this.#mode === "active") {
      this.#reconcileActive(resetKeyChanged);
    } else {
      this.#seedTabStop();
    }
  }

  @bind
  handleKeydown(event: KeyboardEvent): void {
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

    const items = this.#items();
    if (!items.length) {
      return;
    }

    const current = this.#currentIndex(items);
    const columns = this.#columnCount();
    const last = items.length - 1;
    const horizontal =
      this.orientation === "horizontal" || this.orientation === "grid";
    const vertical =
      this.orientation === "vertical" || this.orientation === "grid";

    let next: number | null = null;
    switch (event.key) {
      case "ArrowRight":
        if (horizontal) {
          next = this.#step(current, 1, last);
          if (next == null && current >= 0 && this.onExit) {
            event.preventDefault();
            this.onExit("forward");
            return;
          }
        }
        break;
      case "ArrowLeft":
        if (horizontal) {
          next = this.#step(current, -1, last);
          if (next == null && current >= 0 && this.onExit) {
            event.preventDefault();
            this.onExit("backward");
            return;
          }
        }
        break;
      case "ArrowDown":
        if (vertical) {
          // From no active option (current < 0), Down seeds the first item.
          next = current < 0 ? 0 : this.#stepRow(current, columns, last);
          if (next == null && current >= 0 && this.onEdgeReach) {
            event.preventDefault();
            this.onEdgeReach("forward");
            return;
          }
        }
        break;
      case "ArrowUp":
        if (vertical) {
          // From no active option (current < 0), Up seeds the last item.
          next = current < 0 ? last : this.#stepRow(current, -columns, last);
          if (next == null && current >= 0 && this.onEdgeReach) {
            event.preventDefault();
            this.onEdgeReach("backward");
            return;
          }
        }
        break;
      case "Home":
        if (this.logicalCount != null) {
          this.#jumpToLogicalIndex(0, "backward", event);
          return;
        }
        next = 0;
        break;
      case "End":
        if (this.logicalCount != null) {
          this.#jumpToLogicalIndex(this.logicalCount - 1, "forward", event);
          return;
        }
        next = last;
        break;
      case "PageUp":
        if (this.logicalCount != null) {
          const currentLogical = this.#currentLogicalIndex(items, current);
          this.#jumpToLogicalIndex(
            Math.max(currentLogical - items.length, 0),
            "backward",
            event
          );
          return;
        }
        next = 0;
        break;
      case "PageDown":
        if (this.logicalCount != null) {
          const currentLogical = this.#currentLogicalIndex(items, current);
          this.#jumpToLogicalIndex(
            Math.min(currentLogical + items.length, this.logicalCount - 1),
            "forward",
            event
          );
          return;
        }
        next = last;
        break;
      case "Enter":
      case " ":
        if (current >= 0 && this.onActivate) {
          event.preventDefault();
          this.onActivate(items[current], event);
        }
        return;
      default:
        return;
    }

    // `null` means the key isn't ours, or we're at an edge with no wrap — leave the
    // event un-prevented so a surrounding handler (e.g. a search field above the
    // grid) can act on it.
    if (next == null || next < 0 || next > last) {
      return;
    }
    event.preventDefault();
    this.#setActive(items[next], items);
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
      return document.querySelector<HTMLElement>(controllerElement);
    }
    return null;
  }

  /**
   * The live, usable items in DOM order. Re-queried on every read (never cached) so
   * a consumer that re-renders its list between keystrokes never navigates a stale
   * NodeList.
   */
  #items(): HTMLElement[] {
    if (!this.itemSelector || !this.element) {
      return [];
    }
    return Array.from(
      this.element.querySelectorAll<HTMLElement>(this.itemSelector)
    ).filter((el) => this.#isUsable(el));
  }

  /**
   * Every item matching the selector, usable or not. The highlight bookkeeping reaches for this
   * rather than {@link #items} because a row can leave the usable set *while it holds the
   * highlight* (e.g. it becomes `aria-disabled` on a runtime state change), and its stale
   * `activeClass` must still be cleared even though navigation no longer visits it.
   */
  #allItems(): HTMLElement[] {
    if (!this.itemSelector || !this.element) {
      return [];
    }
    return Array.from(
      this.element.querySelectorAll<HTMLElement>(this.itemSelector)
    );
  }

  // Strips `activeClass` from every item, usable or not, so a row disabled while active does not
  // keep the highlight.
  #clearActiveClass(): void {
    if (!this.activeClass) {
      return;
    }
    for (const el of this.#allItems()) {
      el.classList.remove(this.activeClass);
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
   * Whether an item can be a navigation target — visible and not disabled. Ported
   * from the focusable predicate in `d-tab-to-sibling`, returning real booleans.
   */
  #isUsable(el: HTMLElement): boolean {
    if (
      el.getAttribute("aria-disabled") === "true" ||
      ("disabled" in el && (el as HTMLButtonElement).disabled)
    ) {
      return false;
    }
    // `offsetParent` is null for `display:none` (and `position:fixed`); the
    // client-rects check keeps fixed-position items usable while still rejecting
    // hidden ones.
    if (!el.offsetParent && el.getClientRects().length === 0) {
      return false;
    }
    // `visibility: hidden` still participates in layout, so the checks above
    // pass, yet the element cannot take focus — a `focus()` on it is a no-op and
    // would leave the cursor stranded. Checked last because it is the only check
    // that forces a style resolution.
    if (getComputedStyle(el).visibility !== "visible") {
      return false;
    }
    return true;
  }

  /**
   * The number of columns in the grid, derived from the resolved
   * `grid-template-columns` track list (e.g. `"96px 96px 96px"` → 3) — which the
   * browser resolves even for `repeat(auto-fill, …)`. Falls back to a single column
   * when the value is unresolvable (`none`, a collapsed/`display:none` container, or
   * an unresolved `calc()`/`clamp()` track in some engines); pass `columns` to
   * override for non-grid layouts.
   */
  #columnCount(): number {
    if (typeof this.columnsOverride === "function") {
      return Math.max(1, this.columnsOverride() || 1);
    }
    if (typeof this.columnsOverride === "number") {
      return Math.max(1, this.columnsOverride);
    }
    if (this.orientation !== "grid" || !this.element) {
      return 1;
    }
    const tracks = getComputedStyle(this.element).gridTemplateColumns;
    if (!tracks || tracks === "none") {
      return 1;
    }
    // Count only resolved track tokens; ignore keywords like `subgrid`/`none`.
    const count = tracks
      .trim()
      .split(/\s+/)
      .filter(
        (token) => token && token !== "subgrid" && token !== "none"
      ).length;
    return count >= 1 ? count : 1;
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
  #currentIndex(items: HTMLElement[]): number {
    if (this.#mode === "active") {
      // May be -1 — "no active option yet". Callers treat a negative index as no
      // highlight: Arrow seeds the first/last item, Enter falls through so the
      // consumer can submit or create.
      return items.findIndex((el) => el.id === this.#activeId);
    }
    const active = document.activeElement;
    const focused = items.findIndex(
      (el) => el === active || el.contains(active)
    );
    if (focused >= 0) {
      return focused;
    }
    return items.findIndex((el) => el.tabIndex === 0);
  }

  #currentLogicalIndex(items: HTMLElement[], current: number): number {
    const element = items[current];
    const logical = element?.dataset.logicalIndex ?? element?.dataset.index;
    return logical === undefined ? current : Number(logical);
  }

  #jumpToLogicalIndex(
    target: number,
    direction: "forward" | "backward",
    event: KeyboardEvent
  ): void {
    event.preventDefault();
    if (!this.#api.focusLogicalIndex(target)) {
      this.onJump?.(target, direction);
    }
  }

  /**
   * One step along the row axis, honoring `wrap`.
   */
  #step(index: number, delta: number, last: number): number | null {
    const next = index + delta;
    if (next < 0 || next > last) {
      return this.wrap ? (next + (last + 1)) % (last + 1) : null;
    }
    return next;
  }

  /**
   * One step along the column axis (± one row). Moving down past a ragged last row
   * lands on the last item rather than dead-ending; edges otherwise wrap or stop per
   * `wrap`. `delta` is `+columns` (down) or `-columns` (up).
   */
  #stepRow(index: number, delta: number, last: number): number | null {
    const next = index + delta;
    if (next >= 0 && next <= last) {
      return next;
    }
    if (delta > 0 && index < last) {
      // Down from the last full row onto a shorter row: clamp to the last item.
      return last;
    }
    if (this.wrap) {
      return ((next % (last + 1)) + (last + 1)) % (last + 1);
    }
    return null;
  }

  /**
   * Moves the cursor to `target`: in focus mode, updates the items' tabindex values
   * and moves DOM focus; in active mode, repoints `aria-activedescendant`, moves
   * `activeClass`, and scrolls the item into view without moving focus.
   */
  #setActive(target: HTMLElement, items: HTMLElement[], pointer = false): void {
    if (this.#mode === "active") {
      // Sweep all items, not just the usable ones passed in: the previously-active row may have
      // just been disabled, which drops it from that set while it still carries the class.
      this.#clearActiveClass();
      const id = this.#ensureId(target);
      this.#activeId = id;
      if (this.activeClass) {
        target.classList.add(this.activeClass);
      }
      this.#listenElement?.setAttribute("aria-activedescendant", id);
      this.#scrollActiveIntoView(target);
    } else {
      for (const el of items) {
        el.tabIndex = this.tabStop && el === target ? 0 : -1;
      }
      target.focus();
    }
    this.onActiveChange?.(target, { pointer });
  }

  /**
   * Scrolls the active item into view within its nearest scrollable ancestor ONLY — never the
   * page. `scrollIntoView` scrolls every scrollable ancestor including the window, and while an
   * overlay listbox is portalled and not yet positioned by floating-ui, the item's page position
   * is at the portal root (top of the page), so scrolling the window jumps the whole page to the
   * top. Adjusting only the container's `scrollTop` keeps a long list navigable without ever
   * moving the page; when the only scroller up the tree is the document, it does nothing.
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
    let node = element.parentElement;
    while (
      node &&
      node !== document.body &&
      node !== document.documentElement
    ) {
      const overflowY = getComputedStyle(node).overflowY;
      if (
        (overflowY === "auto" ||
          overflowY === "scroll" ||
          overflowY === "overlay") &&
        node.scrollHeight > node.clientHeight
      ) {
        return node;
      }
      node = node.parentElement;
    }
    return null;
  }

  /**
   * Focus mode — stamps every item with an explicit tabindex. When `tabStop` is
   * enabled, prefers an existing `tabindex="0"`, else an
   * `[aria-selected="true"]`/`[aria-current]` item, else the first item. Does NOT move
   * focus, so re-seeding after a re-render (or while the user is typing in a separate
   * search field) never yanks focus.
   */
  #seedTabStop(): void {
    const items = this.#items();
    // Pick the tab stop from the still-usable items first, preserving an already-established one.
    const preferred =
      items.find((el) => el.tabIndex === 0) ??
      items.find((el) => el.getAttribute("aria-selected") === "true") ??
      items.find((el) => el.hasAttribute("aria-current")) ??
      items[0];
    // Then demote every matching item, usable or not: a row disabled while it held the tab stop
    // has left the usable set, and seeding only across that set would leave its `tabindex="0"` in
    // place as a second, unreachable tab stop.
    for (const el of this.#allItems()) {
      el.tabIndex = -1;
    }
    if (this.tabStop && preferred) {
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
      const selected = this.autoActivateSelected
        ? items.find((el) => el.getAttribute("aria-selected") === "true")
        : undefined;
      const seed = selected ?? this.#autoFirstSeed(items);
      if (seed) {
        this.#disarmPendingSeed();
        this.#setActive(seed, items);
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
      if (!items.length) {
        this.#armPendingSeed();
      }
      this.#activeId = null;
      this.#listenElement?.removeAttribute("aria-activedescendant");
      // Sweep all items: the row that lost the highlight may have left the usable set (disabled)
      // in the same change that cleared the cursor.
      this.#clearActiveClass();
      // Notify the consumer too, so a template-driven highlight (a tracked active key rendered as
      // a class) clears alongside the modifier's own `activeClass` and `aria-activedescendant`.
      this.onActiveChange?.(null);
      return;
    }
    const target = items.find((el) => el.id === this.#activeId);
    if (this.activeClass) {
      this.#clearActiveClass();
      target?.classList.add(this.activeClass);
    }
    this.#listenElement?.setAttribute("aria-activedescendant", this.#activeId!);
  }

  /**
   * Watches the container for the arrival of its first items, then seeds the cursor once and
   * stops. One-shot by construction: the observer disconnects before reconciling, so a container
   * that keeps churning rows is never re-seeded.
   */
  #armPendingSeed(): void {
    if (this.#pendingSeed || !this.element) {
      return;
    }
    if (!this.autoActivateFirst && !this.autoActivateSelected) {
      return;
    }

    this.#pendingSeed = new MutationObserver(() => {
      if (!this.#items().length) {
        return;
      }
      this.#disarmPendingSeed();
      this.#reconcileActive();
    });
    this.#pendingSeed.observe(this.element, {
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
   * Returns nothing when every *mounted usable* item is selected — which a windowed list reaches
   * while unselected rows still exist offscreen. The cursor then stays empty until an Arrow moves
   * it, rather than falling back to a row whose activation would discard a value.
   */
  #autoFirstSeed(items: HTMLElement[]): HTMLElement | undefined {
    if (!this.autoActivateFirst) {
      return undefined;
    }
    if (!this.activationRemovesSelected) {
      return items[0];
    }
    return items.find((el) => el.getAttribute("aria-selected") !== "true");
  }

  /**
   * Returns an item's `id`, minting a stable one (tracked for cleanup) when the
   * author hasn't supplied it — `aria-activedescendant` references items by id.
   */
  #ensureId(el: HTMLElement): string {
    if (!el.id) {
      const id = `${guidFor(this)}-${this.#mintedIds.size}`;
      el.id = id;
      this.#mintedIds.add(id);
    }
    return el.id;
  }

  /**
   * Moves the cursor onto the item a pointer press landed on, so the keyboard continues from
   * where the reader last acted rather than from wherever a re-seed would put it. Ignores a
   * press that missed an item (padding, a group header, a scrollbar) and one on an unusable
   * item, matching what the keyboard already refuses to land on.
   */
  @bind
  handlePointerDown(event: MouseEvent): void {
    if (this.#mode !== "active" || !this.itemSelector) {
      return;
    }
    const target = (event.target as HTMLElement | null)?.closest<HTMLElement>(
      this.itemSelector
    );
    if (!target || !this.#isUsable(target)) {
      return;
    }
    this.#setActive(target, this.#items(), true);
  }

  cleanup(): void {
    this.#disarmPendingSeed();
    if (this.#reannounceTimer) {
      cancel(this.#reannounceTimer);
      this.#reannounceTimer = undefined;
    }
    this.#listenElement?.removeEventListener("keydown", this.handleKeydown);
    this.#pointerElement?.removeEventListener(
      "mousedown",
      this.handlePointerDown
    );
    if (this.#mode === "active") {
      this.#listenElement?.removeAttribute("aria-activedescendant");
      for (const el of this.element?.querySelectorAll<HTMLElement>(
        this.itemSelector ?? "*"
      ) ?? []) {
        if (this.#mintedIds.has(el.id)) {
          el.removeAttribute("id");
        }
        if (this.activeClass) {
          el.classList.remove(this.activeClass);
        }
      }
    }
    this.#mintedIds.clear();
    this.#listenElement = null;
    this.element = null;
    this.#registeredApiCallback?.(null);
    this.#registeredApiCallback = undefined;
  }
}
