import type { DRovingFocusConfig } from "../config";
import {
  fallsBackToFirst,
  findMarked,
  isMarked,
  prefersSelected,
} from "../entry-policy";
import ItemScope from "../item-scope";

/** Maintains the single-tab-stop strategy and focus restoration state. */
export default class RovingTabindexStrategy {
  #scope: ItemScope;
  #config: DRovingFocusConfig;
  /**
   * Items already demoted to `tabindex="-1"`. Identity tracking prevents an incoming authored
   * `tabindex="0"` from creating a second tab stop; weak references do not retain removed items.
   */
  #stamped = new WeakSet<HTMLElement>();
  #tabStopHolder: HTMLElement | null = null;
  /**
   * The last focused item and its raw-item index, retained to distinguish removal from focus
   * moving away and to address its positional replacement.
   */
  #lastFocusedItem: HTMLElement | null = null;
  #lastFocusedIndex = -1;
  /**
   * The previous render's items, used only to distinguish one removal from whole-list replacement.
   */
  #previousItems: HTMLElement[] = [];

  constructor(scope: ItemScope, config: DRovingFocusConfig) {
    this.#scope = scope;
    this.#config = config;
  }

  /** Adopts the latest item scope and configuration. */
  update(scope: ItemScope, config: DRovingFocusConfig): void {
    this.#scope = scope;
    this.#config = config;
  }

  /** Resolves the current item from DOM focus, then the established tab stop. */
  current(items: HTMLElement[]): HTMLElement | null {
    const active = document.activeElement;
    for (let index = items.length - 1; index >= 0; index--) {
      if (items[index] === active || items[index].contains(active)) {
        return items[index];
      }
    }
    return items.find((item) => item.getAttribute("tabindex") === "0") ?? null;
  }

  /** Records focus that entered an item and promotes it as the tab stop. */
  recordFocus(target: HTMLElement): void {
    this.#promote(target);
    this.#lastFocusedItem = target;
    this.#lastFocusedIndex = this.#scope.all().indexOf(target);
  }

  /** Promotes an item and moves DOM focus to it. */
  activate(target: HTMLElement): void {
    this.#promote(target);
    target.focus();
  }

  /**
   * Chooses and stamps the tab stop without moving focus. Seeding controls where a future Tab
   * arrives; it must not pull focus into the group during initial render or reconciliation.
   *
   * @param reseed - Whether to disregard the established tab stop and choose afresh.
   */
  seed(reseed: boolean): void {
    const all = this.#scope.all();
    let preferred: HTMLElement | undefined;
    if (this.#config.tabStop) {
      const navigable = (item: HTMLElement) => this.#scope.isNavigable(item);
      const current = reseed ? null : this.current(all);
      preferred =
        (current && navigable(current) ? current : undefined) ??
        (reseed
          ? undefined
          : all.find(
              (item) => item.getAttribute("tabindex") === "0" && navigable(item)
            )) ??
        (prefersSelected(this.#config)
          ? findMarked(all, navigable)
          : undefined) ??
        (fallsBackToFirst(this.#config)
          ? this.#firstSeed(all, navigable)
          : undefined);
    }
    for (const item of all) {
      if (!this.#stamped.has(item)) {
        item.tabIndex = -1;
        this.#stamped.add(item);
      }
    }
    this.#promote(preferred);
  }

  /**
   * Returns a replacement only when restoration is enabled and the remembered focused item was
   * removed. A surviving prior item proves the group was edited rather than replaced; focus must
   * have fallen to the document body so an intentional move is not reclaimed; and a non-empty
   * group is required because only the consumer can choose an external fallback.
   */
  restorationTarget(): HTMLElement | null {
    const remembered = this.#lastFocusedItem;
    if (!remembered || remembered.isConnected) {
      return null;
    }
    // Forgotten before the opt-out check: a removal declined now must not be acted on by a
    // later run that finds restoration re-enabled, nor retain the detached element.
    this.#lastFocusedItem = null;
    if (!this.#config.restoreLostFocus) {
      return null;
    }
    if (!this.#previousItems.some((item) => item.isConnected)) {
      return null;
    }
    const document = this.#scope.container.ownerDocument;
    if (document.activeElement && document.activeElement !== document.body) {
      return null;
    }
    const all = this.#scope.all();
    if (!all.length) {
      return null;
    }
    const start = Math.min(this.#lastFocusedIndex, all.length - 1);
    for (let index = start; index < all.length; index++) {
      if (this.#scope.isNavigable(all[index])) {
        return all[index];
      }
    }
    for (let index = start - 1; index >= 0; index--) {
      if (this.#scope.isNavigable(all[index])) {
        return all[index];
      }
    }
    return null;
  }

  /** Snapshots the rendered items for removal-versus-replacement detection on the next pass. */
  finishRender(): void {
    this.#previousItems = this.#scope.all();
  }

  /** Removes tab-stop artifacts and releases retained state. */
  destroy(): void {
    for (const item of this.#scope.all()) {
      item.removeAttribute("tabindex");
    }
    this.#stamped = new WeakSet();
    this.#tabStopHolder = null;
    this.#lastFocusedItem = null;
    this.#previousItems = [];
  }

  #promote(target: HTMLElement | undefined): void {
    if (this.#tabStopHolder && this.#tabStopHolder !== target) {
      this.#tabStopHolder.tabIndex = -1;
    }
    this.#tabStopHolder = null;
    if (!target) {
      return;
    }
    target.tabIndex = this.#config.tabStop ? 0 : -1;
    this.#stamped.add(target);
    if (this.#config.tabStop) {
      this.#tabStopHolder = target;
    }
  }

  #firstSeed(
    items: HTMLElement[],
    navigable: (item: HTMLElement) => boolean
  ): HTMLElement | undefined {
    if (!this.#config.fallbackSkipsMarked) {
      return items.find(navigable);
    }
    return (
      items.find((item) => !isMarked(item) && navigable(item)) ??
      items.find(navigable)
    );
  }
}
