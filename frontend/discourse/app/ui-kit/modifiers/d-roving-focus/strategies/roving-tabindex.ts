import type { DRovingFocusConfig } from "../config";
import {
  fallsBackToFirst,
  findMarked,
  isMarked,
  prefersSelected,
} from "../entry-policy";
import ItemScope from "../item-scope";

export default class RovingTabindexStrategy {
  #scope: ItemScope;
  #config: DRovingFocusConfig;
  #stamped = new WeakSet<HTMLElement>();
  #tabStopHolder: HTMLElement | null = null;
  #lastFocusedItem: HTMLElement | null = null;
  #lastFocusedIndex = -1;
  #previousItems: HTMLElement[] = [];

  constructor(scope: ItemScope, config: DRovingFocusConfig) {
    this.#scope = scope;
    this.#config = config;
  }

  update(scope: ItemScope, config: DRovingFocusConfig): void {
    this.#scope = scope;
    this.#config = config;
  }

  current(items: HTMLElement[]): HTMLElement | null {
    const active = document.activeElement;
    for (let index = items.length - 1; index >= 0; index--) {
      if (items[index] === active || items[index].contains(active)) {
        return items[index];
      }
    }
    return items.find((item) => item.getAttribute("tabindex") === "0") ?? null;
  }

  recordFocus(target: HTMLElement): void {
    this.#promote(target);
    this.#lastFocusedItem = target;
    this.#lastFocusedIndex = this.#scope.all().indexOf(target);
  }

  activate(target: HTMLElement): void {
    this.#promote(target);
    target.focus();
  }

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

  restorationTarget(): HTMLElement | null {
    const remembered = this.#lastFocusedItem;
    if (
      !this.#config.restoreLostFocus ||
      !remembered ||
      remembered.isConnected
    ) {
      return null;
    }
    this.#lastFocusedItem = null;
    if (!this.#previousItems.some((item) => item.isConnected)) {
      return null;
    }
    const document = this.#scope.container.ownerDocument;
    if (document.activeElement && document.activeElement !== document.body) {
      return null;
    }
    const all = this.#scope.all();
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

  finishRender(): void {
    this.#previousItems = this.#scope.all();
  }

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
