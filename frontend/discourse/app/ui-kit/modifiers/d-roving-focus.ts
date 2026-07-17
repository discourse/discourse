import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
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
  /** Called whenever the cursor moves to a new item. */
  onActiveChange?: (item: HTMLElement) => void;
  /** Called at a horizontal edge when `wrap` is false; wrapping suppresses it. */
  onExit?: (direction: "forward" | "backward") => void;
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
  /** Active mode: the element that keeps focus (a text input), by `Element` or selector. */
  controllerElement?: Element | string | null;
  /**
   * Active mode only — when true, highlight the first item whenever the cursor has none
   * (initial render, or the active item dropped out on a re-filter), so Enter selects it
   * without an ArrowDown. The WAI-ARIA "list autocomplete with automatic selection"
   * combobox pattern. Default `false` (the cursor starts empty until an Arrow keypress).
   */
  autoActivateFirst?: boolean;
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
  onActiveChange?: (item: HTMLElement) => void;
  onExit?: (direction: "forward" | "backward") => void;
  wrap = false;
  tabStop = true;
  activeClass: string | null = null;
  itemsKey: unknown;
  autoActivateFirst = false;

  /** The element keydown is bound to: the container (focus) or controller (active). */
  #listenElement: HTMLElement | null = null;

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
    this.wrap = named.wrap ?? false;
    this.tabStop = named.tabStop ?? true;
    this.activeClass = named.activeClass ?? null;
    this.autoActivateFirst = named.autoActivateFirst ?? false;
    // Reading `itemsKey` here keeps `modify()` reactive to it; the value itself
    // isn't used beyond triggering a re-run + reconcile.
    this.itemsKey = named.itemsKey;

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

    if (this.#mode === "active") {
      this.#reconcileActive();
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

    // Active mode drives a text-input combobox: the controller (a text input) keeps
    // focus and its caret, so only vertical navigation and Enter activation are ours.
    // Every other key — printable characters, Space, Home/End, Left/Right — must reach
    // the input so typing and caret movement keep working (the WAI-ARIA editable
    // combobox behavior). Escape is owned by the overlay, not this modifier.
    if (
      this.#mode === "active" &&
      event.key !== "ArrowDown" &&
      event.key !== "ArrowUp" &&
      event.key !== "Enter"
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
        }
        break;
      case "ArrowUp":
        if (vertical) {
          // From no active option (current < 0), Up seeds the last item.
          next = current < 0 ? last : this.#stepRow(current, -columns, last);
        }
        break;
      case "Home":
        next = 0;
        break;
      case "End":
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
  #setActive(target: HTMLElement, items: HTMLElement[]): void {
    if (this.#mode === "active") {
      const previous = items.find((el) => el.id === this.#activeId);
      if (previous && this.activeClass) {
        previous.classList.remove(this.activeClass);
      }
      const id = this.#ensureId(target);
      this.#activeId = id;
      if (this.activeClass) {
        target.classList.add(this.activeClass);
      }
      this.#listenElement?.setAttribute("aria-activedescendant", id);
      target.scrollIntoView({ block: "nearest" });
    } else {
      for (const el of items) {
        el.tabIndex = this.tabStop && el === target ? 0 : -1;
      }
      target.focus();
    }
    this.onActiveChange?.(target);
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
    if (!items.length) {
      return;
    }
    if (!this.tabStop) {
      for (const el of items) {
        el.tabIndex = -1;
      }
      return;
    }
    const existing =
      items.find((el) => el.tabIndex === 0) ??
      items.find((el) => el.getAttribute("aria-selected") === "true") ??
      items.find((el) => el.hasAttribute("aria-current")) ??
      items[0];
    for (const el of items) {
      el.tabIndex = el === existing ? 0 : -1;
    }
  }

  /**
   * Active mode — reconciles the highlight after the item set may have changed
   * (`itemsKey`). If the previously-active id is gone (or there was none), clears the
   * highlight so `aria-activedescendant` never points at a removed element; the next
   * Arrow keypress seeds a new active option.
   */
  #reconcileActive(): void {
    const items = this.#items();
    const stillPresent =
      this.#activeId != null && items.some((el) => el.id === this.#activeId);
    if (!stillPresent) {
      // Auto-highlight the first item when asked (combobox automatic-selection). The
      // stale `#activeId` can't match any current element, so `#setActive` finds no
      // previous highlight to clear before it points the cursor at `items[0]`.
      if (this.autoActivateFirst && items.length) {
        this.#setActive(items[0], items);
        return;
      }
      this.#activeId = null;
      this.#listenElement?.removeAttribute("aria-activedescendant");
      if (this.activeClass) {
        for (const el of items) {
          el.classList.remove(this.activeClass);
        }
      }
      return;
    }
    const target = items.find((el) => el.id === this.#activeId);
    if (this.activeClass) {
      for (const el of items) {
        el.classList.toggle(this.activeClass, el === target);
      }
    }
    this.#listenElement?.setAttribute("aria-activedescendant", this.#activeId!);
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

  cleanup(): void {
    this.#listenElement?.removeEventListener("keydown", this.handleKeydown);
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
