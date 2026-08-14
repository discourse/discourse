import { assert } from "@ember/debug";
import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import { createRovingFocusApi } from "./d-roving-focus/api";
import { apiStep } from "./d-roving-focus/api-navigation";
import {
  type DRovingFocusConfig,
  normalizeConfig,
} from "./d-roving-focus/config";
import RovingFocusDiagnostics from "./d-roving-focus/diagnostics";
import ItemScope from "./d-roving-focus/item-scope";
import KeyboardRouter from "./d-roving-focus/keyboard";
import ActiveDescendantStrategy from "./d-roving-focus/strategies/active-descendant";
import RovingTabindexStrategy from "./d-roving-focus/strategies/roving-tabindex";
import type {
  DRovingFocusApi,
  DRovingFocusArgs,
  DRovingFocusSignature,
  DRovingFocusStrategy,
} from "./d-roving-focus/types";

export type {
  DRovingFocusApi,
  DRovingFocusAxis,
  DRovingFocusDisabledItems,
  DRovingFocusEntry,
  DRovingFocusStepResult,
  DRovingFocusStrategy,
} from "./d-roving-focus/types";

/**
 * Keyboard navigation for a one-dimensional list or a two-dimensional grid of
 * items, in DOM order.
 *
 * Its conformance target is the WAI-ARIA Authoring Practices' keyboard-interface practice,
 * https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/ — the sections implemented here
 * are Discernible and Predictable Focus, Navigation Between Components, Navigation Inside
 * Components, and the focusability of disabled controls. Focus VS Selection is split: the
 * modifier owns the indicator, the consumer owns the chosen value.
 *
 * **Where the boundary falls.** Key BINDINGS come from the individual pattern pages, which that
 * document delegates to, and pattern-specific SEMANTICS belong to consumers. So the modifier
 * moves a cursor and reports what happened; what a step, an activation or a cross-axis press
 * MEANS for a tree, a menubar or a treegrid is not its business. A behaviour earns a place here
 * only if it means the same thing in every composite pattern.
 *
 * It implements the two WAI-ARIA "single tab stop" patterns
 * from one engine, chosen with `focusStrategy`:
 *
 * - `"roving-tabindex"` (the default) — exactly one item is reachable with Tab
 *   (`tabindex="0"`) and the rest are set to `tabindex="-1"`; with `tabStop=false` every item is
 *   set to `-1`. Arrow keys move real DOM focus between items and update tabindex along with it.
 *   Use this when the active item should itself hold focus (a tile grid, a toolbar).
 * - `"active-descendant"` — DOM focus stays on a separate controller
 *   element (typically a text input); arrow keys move a *virtual* highlight through
 *   the items by pointing the controller's `aria-activedescendant` at the active
 *   item and toggling `activeClass` on it. Use this for a combobox where the user
 *   must keep typing while navigating results.
 *
 * The single-tab-stop invariant holds as long as the modifier is told when the items change:
 * it only re-runs when a named argument does, so a group whose rows come from state it cannot
 * see must pass `itemsKey`.
 *
 * Navigation is always DOM order, which is a CONSTRAINT ON CONSUMERS rather than an
 * implementation detail: the practice page stresses keeping the navigation order aligned with
 * reading order, and CSS can reorder a grid visually (`order`, `grid-auto-flow: dense`, an
 * explicit line placement) without moving anything in the DOM. Where those disagree the cursor
 * follows the DOM and the reader sees it jump. Order the markup the way it should be read.
 *
 * Row and column arithmetic uses the items that occupy a layout
 * position — a disabled or `visibility: hidden` row still fills its cell, so counting only the
 * navigable ones would land a vertical step a column adrift. The column count is derived from
 * the resolved `grid-template-columns` at keydown time, never from element geometry
 * (`offsetTop`/`offsetLeft`), so a responsive grid that reflows is handled without
 * re-configuration. Only a CSS grid publishes a track list, so a group laid out some other
 * two-dimensional way (wrapping flex, multi-column) navigates on one axis, and says so in
 * development.
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
 *     focusStrategy="active-descendant"
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

  /** The fully-resolved arguments from the latest completed `modify()`. */
  #config: DRovingFocusConfig | null = null;

  /** The live DOM query retained with the configuration that owns its artifacts. */
  #scope: ItemScope | null = null;

  /** The current roving strategy session, when that mode owns the cursor. */
  #rovingStrategy: RovingTabindexStrategy | null = null;

  /** The current active-descendant strategy session, when that mode owns the cursor. */
  #activeStrategy: ActiveDescendantStrategy | null = null;

  /**
   * Items already demoted to `tabindex="-1"` by this group. Keyed on element IDENTITY rather
   * than on whether the attribute is missing: items may arrive carrying an author-supplied
   * `tabindex="0"`, and skipping those would leave the group with more than one tab stop.
   * A `WeakSet` so removed items are not retained.
   */
  #itemSelector?: string;
  #keyboard = new KeyboardRouter();
  #onActiveChange?: (
    item: HTMLElement | null,
    meta?: { pointer: boolean }
  ) => void;

  /** The ARIA anchor: the container (focus) or controller (active). */
  #listenElement: HTMLElement | null = null;

  /** The container the shared `mousedown`/`focusin` listeners are currently bound to. */
  #boundContainer: HTMLElement | null = null;

  /** Armed only while a seed is owed to a container that had no items yet. */

  /** Whether `modify()` has run at least once, so the first run is not mistaken for a reset. */
  #hasRun = false;

  /** Set once a group has reported a two-dimensional layout it cannot measure, so it warns once. */
  #diagnostics = new RovingFocusDiagnostics();

  /**
   * Focus mode — the item that last held focus, and its index among ALL items, navigable or not.
   * Kept so a removal can be told apart from focus simply moving away, and so the replacement
   * item can be addressed positionally once the old one is gone.
   */
  /**
   * The items present at the end of the previous `modify()`. Only ever asked whether ANY of them
   * survives, which is what separates an item being deleted from the whole list being replaced.
   */

  /**
   * Monotonic counter behind minted ids. Never reset, so an id cannot be reissued to a second
   * element while the first still carries it — which the set's size would allow after a mode or
   * selector change clears the bookkeeping.
   */
  #mintCounter = 0;

  /** Pending restore of a dropped `aria-activedescendant` — see `reannounceActive`. */

  /**
   * The last `resetKey` seen. The sentinel is a fresh symbol so the first `modify()` always counts
   * as a change — harmless, since there is no cursor yet to preserve, and it keeps the "unset"
   * case from colliding with a consumer that legitimately passes `undefined`.
   */
  #resetKey: unknown = Symbol("unset");

  #mode: DRovingFocusStrategy = "roving-tabindex";

  /** Stable controls registered with the consumer for moving the cursor within the group. */
  #api: DRovingFocusApi = createRovingFocusApi({
    items: () => this.#items(),
    currentItem: () => {
      const cells = this.#cells();
      return this.#currentElement(cells);
    },
    activate: (item) => this.#setActive(item),
    clear: () => {
      if (
        this.#mode !== "active-descendant" ||
        !this.#activeStrategy?.clear()
      ) {
        return false;
      }
      this.#onActiveChange?.(null);
      return true;
    },
    step: (axis, delta) => {
      if (!this.#config || !this.#scope) {
        return "unavailable";
      }
      return apiStep(axis, delta, {
        config: this.#config,
        scope: this.#scope,
        current: (items) => this.#currentElement(items),
        activate: (item) => this.#setActive(item),
        columnCount: () => this.#columnCount(),
      });
    },
    reannounce: () => this.#activeStrategy?.reannounce() ?? false,
  });

  /**
   * Active mode only — the set of item `id`s this modifier minted, so cleanup
   * removes only its own and never strips an author-supplied id.
   */
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
    if (!this.#config || !this.#scope) {
      return;
    }
    this.#keyboard.handle(event, {
      config: this.#config,
      scope: this.#scope,
      controller: this.#listenElement,
      api: this.#api,
      diagnostics: this.#diagnostics,
      current: (items) => this.#currentElement(items),
      columnCount: () => this.#columnCount(),
      activate: (item) => this.#setActive(item),
    });
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
    if (this.#mode !== "active-descendant" || !this.#itemSelector) {
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

  /**
   * Focus mode — keeps the tab stop on whichever item actually holds focus, so the group is
   * re-entered where the reader left it rather than where seeding put it. Without this, clicking
   * the fifth option, tabbing away and tabbing back lands on the first.
   *
   * Bound on `focusin` rather than extended from the pointer handler because focus also arrives
   * with no pointer event at all, and a pointer-only fix would leave those cases behind.
   *
   * Only restamps; it never moves focus and never reports a cursor move. The cursor is already
   * wherever focus is, so calling {@link DRovingFocusArgs.onActiveChange} here would report a
   * move that the arrow path has already reported, or invent one the reader did not make.
   */
  #handleFocusIn = (event: FocusEvent): void => {
    if (this.#mode !== "roving-tabindex" || !this.#itemSelector) {
      return;
    }
    const target = (event.target as HTMLElement | null)?.closest<HTMLElement>(
      this.#itemSelector
    );
    // `closest` walks past the container, so a matching ANCESTOR would otherwise be promoted
    // into a tab stop this group never owned.
    if (!target || !this.#element?.contains(target)) {
      return;
    }
    if (!this.#isNavigable(target)) {
      return;
    }
    this.#rovingStrategy?.recordFocus(target);
  };

  constructor(owner: Owner, args: ArgsFor<DRovingFocusSignature>) {
    super(owner, args);
    registerDestructor(this, () => {
      this.#cleanup();
    });
  }

  /**
   * Reads the named args, (re)binds the keydown listener to the right element, and
   * seeds the cursor. Re-runs whenever a tracked arg changes — passing
   * `itemsKey=this.query` is how a filtering consumer asks the modifier to
   * re-reconcile the cursor against a freshly-rendered item set.
   */
  modify(element: HTMLElement, _positional: [], named: DRovingFocusArgs): void {
    const config = normalizeConfig(named);
    const previousMode = this.#config?.focusStrategy ?? this.#mode;
    const previousItemSelector =
      this.#config?.itemSelector ?? this.#itemSelector;
    const nextMode = config.focusStrategy;

    // Everything the previous configuration wrote has to be swept BEFORE the new arguments are
    // adopted, because every sweep resolves items through the CURRENT `itemSelector` and class.
    // Adopting them first would aim the cleanup at the new item set and strand the old one.
    if (
      previousItemSelector !== config.itemSelector ||
      previousMode !== nextMode
    ) {
      this.#exitEnteredModes();
    }

    this.#element = element;
    this.#config = config;
    this.#scope = new ItemScope(
      element,
      config.itemSelector,
      config.disabledItems
    );
    if (nextMode === "roving-tabindex") {
      if (this.#rovingStrategy) {
        this.#rovingStrategy.update(this.#scope, config);
      } else {
        this.#rovingStrategy = new RovingTabindexStrategy(this.#scope, config);
      }
    }
    this.#mode = nextMode;
    // Asserted rather than merely typed: a consumer casting this modifier to a hand-written
    // `ModifierLike` signature bypasses the type entirely, and without a selector the group binds
    // its listener, matches nothing, and silently swallows every key.
    assert(
      "dRovingFocus requires an `itemSelector` matching the navigable items",
      config.itemSelector
    );
    this.#itemSelector = config.itemSelector;
    this.#keyboard.configure(config);
    this.#onActiveChange = config.onActiveChange;
    // Never on the first run: the sentinel guarantees a difference there, and treating that as a
    // reset would discard an author-supplied `tabindex="0"` before the group has done anything.
    const resetKeyChanged = this.#hasRun && config.resetKey !== this.#resetKey;
    this.#resetKey = config.resetKey;
    this.#hasRun = true;

    const listenElement =
      this.#mode === "active-descendant"
        ? this.#resolveController(config.controllerElement)
        : element;

    if (nextMode === "active-descendant") {
      if (this.#activeStrategy) {
        this.#activeStrategy.update(this.#scope, config, listenElement);
      } else {
        this.#activeStrategy = new ActiveDescendantStrategy(
          this.#scope,
          config,
          listenElement,
          () => `${guidFor(this)}-${this.#mintCounter++}`,
          () => this.#reconcileActive()
        );
      }
    }

    // Rebind only when the listener target changes (the controller element can be
    // swapped, or arrive late once its own `didInsert` has run).
    if (this.#listenElement !== listenElement) {
      this.#listenElement?.removeEventListener("keydown", this.#handleKeydown);
      // The outgoing controller must not keep pointing at an option it no longer controls.
      this.#listenElement?.removeAttribute("aria-activedescendant");
      this.#listenElement = listenElement ?? null;
      this.#listenElement?.addEventListener("keydown", this.#handleKeydown);
    }

    // Bound to the container, not the items, because items come and go. `mousedown` rather than
    // click so the cursor is in place before any consumer handler rebuilds the list: otherwise
    // activating by pointer leaves the reconcile below with no cursor to preserve, and it seeds
    // one at the top — marking a row the reader never touched and pointing
    // `aria-activedescendant` at it.
    if (this.#boundContainer !== element) {
      this.#boundContainer?.removeEventListener(
        "mousedown",
        this.#handlePointerDown
      );
      this.#boundContainer?.removeEventListener("focusin", this.#handleFocusIn);
      this.#boundContainer = element;
      element.addEventListener("mousedown", this.#handlePointerDown);
      element.addEventListener("focusin", this.#handleFocusIn);
    }

    // Recorded before seeding, since seeding is the act that writes to the DOM.
    if (this.#mode === "active-descendant") {
      this.#diagnostics.warnMissingFocusIndicator(
        Boolean(config.activeClass || config.onActiveChange)
      );
      this.#reconcileActive(resetKeyChanged);
    } else {
      this.#rovingStrategy?.seed(resetKeyChanged);
      const restoration = this.#rovingStrategy?.restorationTarget();
      if (restoration) {
        this.#setActive(restoration);
      }
    }
    // Recorded last, so the next run compares against what this one ended with.
    this.#rovingStrategy?.finishRender();

    // Registered last, so a consumer that drives the cursor from inside the callback acts on a
    // bound listener and an already-seeded group.
    if (this.#registeredApiCallback !== config.onRegisterApi) {
      // Tell the superseded holder its registration has ended. The handle it already has stays
      // functional while the modifier lives — there is one shared API object, and only teardown
      // makes it inert — so this is a notification, not a revocation.
      this.#registeredApiCallback?.(null);
      this.#registeredApiCallback = config.onRegisterApi;
      config.onRegisterApi?.(this.#api);
    }
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
    return this.#scope?.items() ?? [];
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
    return this.#scope?.cells() ?? [];
  }

  /**
   * Whether an item can be a navigation target — it occupies space, is not hidden, and is not
   * disabled in a way that would refuse focus. Which disabled items qualify is
   * {@link DRovingFocusArgs.disabledItems}; the native spelling never does.
   *
   * @param el - The candidate item.
   * @returns `true` when the cursor may rest on the item.
   */
  #isNavigable(el: HTMLElement): boolean {
    return this.#scope?.isNavigable(el) ?? false;
  }

  /**
   * The number of columns the cursor navigates by.
   *
   * Only a `"grid"` group in `"roving-tabindex"` mode has a second axis, so both other cases resolve to one
   * column without measuring anything. Active mode leaves the horizontal arrows to its
   * controller's caret, so its cursor can never reach a second column — deriving one would
   * strand every item outside the first.
   *
   * Otherwise derived from the resolved `grid-template-columns` track list
   * (e.g. `"96px 96px 96px"` → 3), which the browser resolves even for `repeat(auto-fill, …)`,
   * so a responsive grid that reflows needs no re-configuration. Falls back to a single column
   * when the computed value is empty or `none`.
   *
   * @returns The column count, at least 1.
   */
  #columnCount(): number {
    if (
      this.#mode === "active-descendant" ||
      this.#config?.orientation !== "grid"
    ) {
      return 1;
    }
    if (!this.#element) {
      return 1;
    }
    // One read serves both the track list and the degradation check below, so the diagnostic
    // costs no extra style resolution.
    const style = getComputedStyle(this.#element);
    const tracks = style.gridTemplateColumns;
    // Named grid lines survive into the computed value (`[full-start] 300px [mid] 300px`) and
    // are not tracks; counting them reads a two-track grid as five columns. `subgrid` is not a
    // track either.
    const count =
      !tracks || tracks === "none"
        ? 1
        : tracks
            .trim()
            .replace(/\[[^\]]*\]/g, " ")
            .split(/\s+/)
            .filter((token) => token && token !== "subgrid").length || 1;
    if (count === 1) {
      this.#diagnostics.warnUndetectedSecondAxis(style);
    }
    return count;
  }

  /**
   * Warns, once per group, when a container that LOOKS two-dimensional resolved to one column.
   *
   * Only a CSS grid publishes a track list, so a flex-wrap or multi-column tile set reports a
   * single column and its second axis silently disappears — the cursor steps one tile at a time
   * where the reader sees rows. Deliberately narrow: a plain block container resolving to one
   * column is the overwhelmingly common case and is CORRECT, so warning on every such group
   * would train the warning away. The fix is to lay the group out with CSS grid, which is also
   * what makes the derivation responsive.
   *
   * @param style - The container's resolved style, already read for the track list.
   */
  /**
   * Resolves the cursor to an ELEMENT, mirroring {@link #currentIndex} but over the raw item set,
   * so nothing has to be measured to find it. Deliberately the same resolution order — active id,
   * then innermost-first containment of `document.activeElement`, then the established tab stop —
   * so the two can never disagree about which item holds the cursor.
   */
  #currentElement(items: HTMLElement[]): HTMLElement | null {
    if (this.#mode === "active-descendant") {
      return this.#activeStrategy?.current(items) ?? null;
    }
    return this.#rovingStrategy?.current(items) ?? null;
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
    if (this.#mode === "active-descendant") {
      this.#activeStrategy!.activate(target);
      this.#diagnostics.warnUnreachableActiveDescendant(
        this.#listenElement,
        target
      );
    } else {
      this.#rovingStrategy?.activate(target);
    }
    this.#onActiveChange?.(target, { pointer });
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
    const result = this.#activeStrategy?.reconcile(reseed);
    if (result?.kind === "activate") {
      this.#setActive(result.target);
    } else if (result?.kind === "cleared") {
      this.#onActiveChange?.(null);
    }
  }

  /**
   * Undoes everything every mode this instance actually ran in wrote to the DOM. Branching on
   * whichever mode happens to be current would strand the other one's artifacts, while exiting
   * modes that never ran would remove attributes the author owns.
   */
  #exitEnteredModes(): void {
    this.#activeStrategy?.destroy();
    this.#activeStrategy = null;
    this.#rovingStrategy?.destroy();
    this.#rovingStrategy = null;
  }

  /**
   * Releases every listener, observer and timer, and gives back everything either mode wrote to
   * the DOM. Registered as the destructor, so it also tells the consumer its registration has
   * ended. That notification is final, unlike the one a supersede sends: every API method
   * reports failure once the modifier is torn down.
   */
  #cleanup(): void {
    this.#keyboard.destroy();
    this.#activeStrategy?.disarmPendingSeed();
    this.#listenElement?.removeEventListener("keydown", this.#handleKeydown);
    this.#boundContainer?.removeEventListener(
      "mousedown",
      this.#handlePointerDown
    );
    this.#boundContainer?.removeEventListener("focusin", this.#handleFocusIn);
    // Every mode this instance ran in, not just the current one: a modifier that spent part of
    // its life in active mode and ended in focus mode still has that mode's ids and attribute to
    // give back.
    this.#exitEnteredModes();
    this.#listenElement = null;
    this.#boundContainer = null;
    this.#rovingStrategy = null;
    this.#activeStrategy = null;
    this.#element = null;
    this.#scope = null;
    this.#config = null;
    this.#registeredApiCallback?.(null);
    this.#registeredApiCallback = undefined;
  }
}
