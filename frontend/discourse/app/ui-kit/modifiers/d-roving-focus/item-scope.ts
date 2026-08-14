import type { DRovingFocusDisabledItems } from "./types";

/** Queries an item group and applies its navigation eligibility rules. */
export default class ItemScope {
  constructor(
    readonly container: HTMLElement,
    readonly selector: string,
    readonly disabledItems: DRovingFocusDisabledItems
  ) {}

  /** Returns every selector-matched item in DOM order. */
  all(): HTMLElement[] {
    return Array.from(
      this.container.querySelectorAll<HTMLElement>(this.selector)
    );
  }

  /** Returns the items the cursor may land on. */
  items(): HTMLElement[] {
    return this.all().filter((item) => this.isNavigable(item));
  }

  /** Returns the items that occupy positions in the navigation coordinate space. */
  cells(): HTMLElement[] {
    return this.all().filter((item) => this.occupiesLayout(item));
  }

  /**
   * Whether activation is allowed; deliberately narrower than navigation eligibility because a
   * disabled item may remain discoverable without becoming operable.
   */
  isActivatable(item: HTMLElement): boolean {
    return !this.isAriaDisabled(item) && this.isNavigable(item);
  }

  /** Whether the cursor may land on an item. */
  isNavigable(item: HTMLElement): boolean {
    if (this.disabledItems === "skip" && this.isAriaDisabled(item)) {
      return false;
    }
    // The selector also catches controls disabled through an ancestor fieldset, unlike the IDL
    // property on the candidate alone.
    if (item.matches(":disabled")) {
      return false;
    }
    // Inertness applies to descendants, so checking only the candidate's attribute is insufficient.
    if (item.closest("[inert]")) {
      return false;
    }
    if (!this.occupiesLayout(item)) {
      return false;
    }
    // Visibility is checked last because resolving computed style is the expensive predicate.
    return getComputedStyle(item).visibility === "visible";
  }

  /**
   * Whether an item occupies layout; client rects retain fixed-position items that have no
   * `offsetParent` while still excluding items removed from layout.
   */
  occupiesLayout(item: HTMLElement): boolean {
    return Boolean(item.offsetParent) || item.getClientRects().length > 0;
  }

  /** Returns whether the item carries the enabled ARIA-disabled state. */
  isAriaDisabled(item: HTMLElement): boolean {
    return item.getAttribute("aria-disabled") === "true";
  }
}
