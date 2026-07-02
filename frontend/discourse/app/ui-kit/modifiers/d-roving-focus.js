import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

/**
 * Keyboard navigation for a one-dimensional list or a two-dimensional grid of
 * items, in DOM order. It implements the two WAI-ARIA "single tab stop" patterns
 * from one engine, chosen with `selectionMode`:
 *
 * - `"focus"` (the default) — a roving tabindex. Exactly one item is reachable
 *   with Tab (`tabindex="0"`); the rest are `tabindex="-1"`. Arrow keys move real
 *   DOM focus between items and flip the single tab stop along with it. Use this
 *   when the active item should itself hold focus (a tile grid, a toolbar).
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
 *
 * @example Roving-tabindex tile grid
 * <div role="listbox" {{dRovingFocus itemSelector=".tile" onActivate=this.pick}}>
 *   <button role="option" class="tile">…</button>
 *   …
 * </div>
 *
 * @example Combobox (focus stays in the input)
 * <input role="combobox" aria-controls="results" />
 * <div id="results" role="listbox" {{dRovingFocus
 *   selectionMode="active"
 *   controllerElement=this.inputElement
 *   itemSelector=".tile"
 *   itemsKey=this.query
 *   activeClass="--active"
 *   onActivate=this.pick
 * }}>…</div>
 */
export default class DRovingFocusModifier extends Modifier {
  /** The element the modifier is attached to (the items' container). */
  element = null;

  /** The element keydown is bound to: the container (focus) or controller (active). */
  #listenElement = null;

  /** `"focus"` | `"active"`. */
  #mode = "focus";

  /**
   * Active mode only — the `id` of the currently-highlighted item. Tracked here
   * rather than read back off the DOM so a re-render that drops the element can be
   * reconciled against the live item set.
   */
  #activeId = null;

  /** Active mode only — the set of item `id`s this modifier minted, so cleanup
   * removes only its own and never strips an author-supplied id. */
  #mintedIds = new Set();

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  /**
   * Reads the named args, (re)binds the keydown listener to the right element, and
   * seeds the cursor. Re-runs whenever a tracked arg changes — passing
   * `itemsKey=this.query` is how a filtering consumer asks the modifier to
   * re-reconcile the cursor against a freshly-rendered item set.
   *
   * @param {Element} element - The items' container.
   * @param {Array} _positional - Unused.
   * @param {Object} named - The named args (see the class JSDoc for the full list).
   */
  modify(element, _positional, named) {
    this.element = element;
    this.#mode = named.selectionMode ?? "focus";
    this.orientation = named.orientation ?? "grid";
    this.itemSelector = named.itemSelector;
    this.columnsOverride = named.columns ?? null;
    this.onActivate = named.onActivate;
    this.onActiveChange = named.onActiveChange;
    this.wrap = named.wrap ?? false;
    this.activeClass = named.activeClass ?? null;
    // Reading `itemsKey` here keeps `modify()` reactive to it; the value itself
    // isn't used beyond triggering a re-run + reconcile.
    this.itemsKey = named.itemsKey;

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
  handleKeydown(event) {
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

    let next = null;
    switch (event.key) {
      case "ArrowRight":
        if (horizontal) {
          next = this.#step(current, 1, last);
        }
        break;
      case "ArrowLeft":
        if (horizontal) {
          next = this.#step(current, -1, last);
        }
        break;
      case "ArrowDown":
        if (vertical) {
          next = this.#stepRow(current, columns, last);
        }
        break;
      case "ArrowUp":
        if (vertical) {
          next = this.#stepRow(current, -columns, last);
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
   *
   * @param {Element|string|undefined} controllerElement
   * @returns {Element|null}
   */
  #resolveController(controllerElement) {
    if (controllerElement instanceof Element) {
      return controllerElement;
    }
    if (typeof controllerElement === "string") {
      return document.querySelector(controllerElement);
    }
    return null;
  }

  /**
   * The live, usable items in DOM order. Re-queried on every read (never cached) so
   * a consumer that re-renders its list between keystrokes never navigates a stale
   * NodeList.
   *
   * @returns {Element[]}
   */
  #items() {
    if (!this.itemSelector) {
      return [];
    }
    return Array.from(this.element.querySelectorAll(this.itemSelector)).filter(
      (el) => this.#isUsable(el)
    );
  }

  /**
   * Whether an item can be a navigation target — visible and not disabled. Ported
   * from the focusable predicate in `d-tab-to-sibling`, returning real booleans.
   *
   * @param {Element} el
   * @returns {boolean}
   */
  #isUsable(el) {
    if (el.getAttribute("aria-disabled") === "true" || el.disabled) {
      return false;
    }
    // `offsetParent` is null for `display:none` (and `position:fixed`); the
    // client-rects check keeps fixed-position items usable while still rejecting
    // hidden ones.
    if (!el.offsetParent && el.getClientRects().length === 0) {
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
   *
   * @returns {number}
   */
  #columnCount() {
    if (typeof this.columnsOverride === "function") {
      return Math.max(1, this.columnsOverride() || 1);
    }
    if (typeof this.columnsOverride === "number") {
      return Math.max(1, this.columnsOverride);
    }
    if (this.orientation !== "grid") {
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
   *
   * @param {Element[]} items
   * @returns {number}
   */
  #currentIndex(items) {
    if (this.#mode === "active") {
      const byId = items.findIndex((el) => el.id === this.#activeId);
      return byId >= 0 ? byId : 0;
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
   *
   * @param {number} index
   * @param {number} delta
   * @param {number} last
   * @returns {number|null}
   */
  #step(index, delta, last) {
    const next = index + delta;
    if (next < 0 || next > last) {
      return this.wrap ? (next + (last + 1)) % (last + 1) : null;
    }
    return next;
  }

  /**
   * One step along the column axis (± one row). Moving down past a ragged last row
   * lands on the last item rather than dead-ending; edges otherwise wrap or stop per
   * `wrap`.
   *
   * @param {number} index
   * @param {number} delta - `+columns` (down) or `-columns` (up).
   * @param {number} last
   * @returns {number|null}
   */
  #stepRow(index, delta, last) {
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
   * Moves the cursor to `target`: in focus mode, flips the single tab stop and moves
   * DOM focus; in active mode, repoints `aria-activedescendant`, moves `activeClass`,
   * and scrolls the item into view without moving focus.
   *
   * @param {Element} target
   * @param {Element[]} items
   */
  #setActive(target, items) {
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
        el.tabIndex = el === target ? 0 : -1;
      }
      target.focus();
    }
    this.onActiveChange?.(target);
  }

  /**
   * Focus mode — ensures exactly one item is the tab stop. Prefers an existing
   * `tabindex="0"`, else an `[aria-selected="true"]`/`[aria-current]` item, else the
   * first item. Does NOT move focus, so re-seeding after a re-render (or while the
   * user is typing in a separate search field) never yanks focus.
   */
  #seedTabStop() {
    const items = this.#items();
    if (!items.length) {
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
   * (`itemsKey`). If the previously-active id is gone, resets the cursor to the
   * first item so `aria-activedescendant` never points at a removed element.
   */
  #reconcileActive() {
    const items = this.#items();
    if (!items.length) {
      this.#activeId = null;
      this.#listenElement?.removeAttribute("aria-activedescendant");
      return;
    }
    const stillPresent = items.some((el) => el.id === this.#activeId);
    const target = stillPresent
      ? items.find((el) => el.id === this.#activeId)
      : items[0];
    if (this.activeClass) {
      for (const el of items) {
        el.classList.toggle(this.activeClass, el === target);
      }
    }
    this.#activeId = this.#ensureId(target);
    this.#listenElement?.setAttribute("aria-activedescendant", this.#activeId);
  }

  /**
   * Returns an item's `id`, minting a stable one (tracked for cleanup) when the
   * author hasn't supplied it — `aria-activedescendant` references items by id.
   *
   * @param {Element} el
   * @returns {string}
   */
  #ensureId(el) {
    if (!el.id) {
      const id = `${guidFor(this)}-${this.#mintedIds.size}`;
      el.id = id;
      this.#mintedIds.add(id);
    }
    return el.id;
  }

  cleanup() {
    this.#listenElement?.removeEventListener("keydown", this.handleKeydown);
    if (this.#mode === "active") {
      this.#listenElement?.removeAttribute("aria-activedescendant");
      for (const el of this.element?.querySelectorAll(
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
  }
}
