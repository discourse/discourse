import { cancel, next as nextRunloop } from "@ember/runloop";
import type { DRovingFocusConfig } from "../config";
import { activeSeed } from "../entry-policy";
import ItemScope from "../item-scope";

export type ActiveReconcileResult =
  | { kind: "preserved" }
  | { kind: "activate"; target: HTMLElement }
  | { kind: "cleared" };

export default class ActiveDescendantStrategy {
  #scope: ItemScope;
  #config: DRovingFocusConfig;
  #controller: HTMLElement | null;
  #activeId: string | null = null;
  #mintedIds = new Set<string>();
  #pendingSeed: MutationObserver | null = null;
  #reannounceTimer?: ReturnType<typeof nextRunloop>;
  #destroyed = false;

  constructor(
    scope: ItemScope,
    config: DRovingFocusConfig,
    controller: HTMLElement | null,
    readonly mintId: () => string,
    readonly onItemsArrived: () => void
  ) {
    this.#scope = scope;
    this.#config = config;
    this.#controller = controller;
  }

  get activeId(): string | null {
    return this.#activeId;
  }

  update(
    scope: ItemScope,
    config: DRovingFocusConfig,
    controller: HTMLElement | null
  ): void {
    if (this.#config.activeClass !== config.activeClass) {
      this.#clearClass(this.#config.activeClass, this.#scope);
    }
    if (this.#controller !== controller) {
      this.#cancelReannounce();
      this.#controller?.removeAttribute("aria-activedescendant");
      this.#controller = controller;
    }
    this.#scope = scope;
    this.#config = config;
  }

  current(items: HTMLElement[]): HTMLElement | null {
    return items.find((item) => item.id === this.#activeId) ?? null;
  }

  activate(target: HTMLElement): string {
    this.#clearClass(this.#config.activeClass, this.#scope);
    const id = this.#ensureId(target);
    this.#activeId = id;
    if (this.#config.activeClass) {
      target.classList.add(this.#config.activeClass);
    }
    this.#controller?.setAttribute("aria-activedescendant", id);
    this.#scrollIntoView(target);
    return id;
  }

  clear(): boolean {
    if (!this.#activeId) {
      return false;
    }
    this.#activeId = null;
    this.#controller?.removeAttribute("aria-activedescendant");
    this.#clearClass(this.#config.activeClass, this.#scope);
    return true;
  }

  reannounce(): boolean {
    const id = this.#activeId;
    const controller = this.#controller;
    if (
      !id ||
      !controller ||
      !this.#scope.items().some((item) => item.id === id)
    ) {
      return false;
    }
    controller.removeAttribute("aria-activedescendant");
    this.#cancelReannounce();
    this.#reannounceTimer = nextRunloop(() => {
      this.#reannounceTimer = undefined;
      if (
        !this.#destroyed &&
        this.#controller === controller &&
        this.#activeId === id &&
        this.#scope.items().some((item) => item.id === id)
      ) {
        controller.setAttribute("aria-activedescendant", id);
      }
    });
    return true;
  }

  armPendingSeed(): void {
    if (this.#pendingSeed || this.#config.entryFocus === "none") {
      return;
    }
    this.#pendingSeed = new MutationObserver(() => {
      if (this.#destroyed || this.#config.entryFocus === "none") {
        this.disarmPendingSeed();
        return;
      }
      if (!this.#scope.items().length) {
        return;
      }
      this.disarmPendingSeed();
      this.onItemsArrived();
    });
    this.#pendingSeed.observe(this.#scope.container, {
      childList: true,
      subtree: true,
    });
  }

  disarmPendingSeed(): void {
    this.#pendingSeed?.disconnect();
    this.#pendingSeed = null;
  }

  reconcile(reseed: boolean): ActiveReconcileResult {
    const items = this.#scope.items();
    const current = reseed ? null : this.current(items);
    if (current) {
      if (this.#config.activeClass) {
        this.#clearClass(this.#config.activeClass, this.#scope);
        current.classList.add(this.#config.activeClass);
      }
      this.#controller?.setAttribute("aria-activedescendant", this.#activeId!);
      return { kind: "preserved" };
    }

    const seed = activeSeed(items, this.#config);
    if (seed) {
      this.disarmPendingSeed();
      return { kind: "activate", target: seed };
    }
    if (!items.length) {
      this.armPendingSeed();
    }
    this.#activeId = null;
    this.#controller?.removeAttribute("aria-activedescendant");
    this.#clearClass(this.#config.activeClass, this.#scope);
    return { kind: "cleared" };
  }

  destroy(): void {
    this.#destroyed = true;
    this.disarmPendingSeed();
    this.#cancelReannounce();
    this.#controller?.removeAttribute("aria-activedescendant");
    this.#clearClass(this.#config.activeClass, this.#scope);
    for (const item of this.#scope.all()) {
      if (this.#mintedIds.has(item.id)) {
        item.removeAttribute("id");
      }
    }
    this.#mintedIds.clear();
    this.#activeId = null;
  }

  #ensureId(item: HTMLElement): string {
    if (!item.id) {
      const id = this.mintId();
      item.id = id;
      this.#mintedIds.add(id);
    }
    return item.id;
  }

  #clearClass(className: string | null, scope: ItemScope): void {
    if (!className) {
      return;
    }
    for (const item of scope.all()) {
      item.classList.remove(className);
    }
  }

  #cancelReannounce(): void {
    if (this.#reannounceTimer) {
      cancel(this.#reannounceTimer);
      this.#reannounceTimer = undefined;
    }
  }

  #scrollIntoView(target: HTMLElement): void {
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

  #scrollableAncestor(element: HTMLElement): HTMLElement | null {
    let node: HTMLElement | null = element.parentElement;
    while (
      node &&
      node !== document.body &&
      node !== document.documentElement
    ) {
      const overflowY = getComputedStyle(node).overflowY;
      if (overflowY === "auto" || overflowY === "scroll") {
        return node;
      }
      node = node.parentElement;
    }
    return null;
  }
}
