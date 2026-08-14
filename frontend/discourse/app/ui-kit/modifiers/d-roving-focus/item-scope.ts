import type { DRovingFocusDisabledItems } from "./types";

export default class ItemScope {
  constructor(
    readonly container: HTMLElement,
    readonly selector: string,
    readonly disabledItems: DRovingFocusDisabledItems
  ) {}

  all(): HTMLElement[] {
    return Array.from(
      this.container.querySelectorAll<HTMLElement>(this.selector)
    );
  }

  items(): HTMLElement[] {
    return this.all().filter((item) => this.isNavigable(item));
  }

  cells(): HTMLElement[] {
    return this.all().filter((item) => this.occupiesLayout(item));
  }

  isActivatable(item: HTMLElement): boolean {
    return !this.isAriaDisabled(item) && this.isNavigable(item);
  }

  isNavigable(item: HTMLElement): boolean {
    if (this.disabledItems === "skip" && this.isAriaDisabled(item)) {
      return false;
    }
    if (item.matches(":disabled")) {
      return false;
    }
    if (item.closest("[inert]")) {
      return false;
    }
    if (!this.occupiesLayout(item)) {
      return false;
    }
    return getComputedStyle(item).visibility === "visible";
  }

  occupiesLayout(item: HTMLElement): boolean {
    return Boolean(item.offsetParent) || item.getClientRects().length > 0;
  }

  isAriaDisabled(item: HTMLElement): boolean {
    return item.getAttribute("aria-disabled") === "true";
  }
}
