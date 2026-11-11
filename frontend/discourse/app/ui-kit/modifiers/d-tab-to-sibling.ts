import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";

interface DTabToSiblingSignature {
  Element: HTMLElement;
}

/**
 * Modifier that redirects tab navigation to focus sibling elements
 * instead of children within the element.
 *
 * Usage: `{{dTabToSibling}}`
 *
 * When Tab is pressed on the element, it will focus the next sibling.
 * When Shift+Tab is pressed, it will focus the previous sibling.
 * If no focusable sibling is found, falls back to default behavior.
 *
 * @example Use on list items to navigate between them instead of focusing children.
 * ```hbs
 * <div class="search-results">
 *   {{#each items as |item|}}
 *     <div class="search-result" {{dTabToSibling}} tabindex="0">
 *       <h3>{{item.title}}</h3>
 *       <button>Action</button>  <!-- Tab won't focus this -->
 *     </div>
 *   {{/each}}
 * </div>
 * ```
 */
export default class DTabToSiblingModifier extends Modifier<DTabToSiblingSignature> {
  declare element: HTMLElement;

  /**
   * @param owner - The owner object
   * @param args - Arguments passed to the modifier
   */
  constructor(owner: Owner, args: ArgsFor<DTabToSiblingSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  /**
   * Applies the modifier to the element
   * @param element - The DOM element to apply the modifier to
   */
  modify(element: HTMLElement) {
    this.element = element;
    this.element.addEventListener("keydown", this.handleKeydown);
  }

  /**
   * Handles keydown events to manage tab navigation
   * @param event - The keyboard event
   */
  @bind
  handleKeydown(event: KeyboardEvent) {
    if (event.key !== "Tab") {
      return;
    }

    let targetSibling;
    if (event.shiftKey) {
      targetSibling = this.findFocusableSibling(this.element, "previous");
    } else {
      targetSibling = this.findFocusableSibling(this.element, "next");
    }

    if (targetSibling) {
      event.preventDefault();
      targetSibling.focus();
    }
  }

  /**
   * Finds the next or previous focusable sibling element
   * @param element - The current element
   * @param direction - "next" or "previous"
   * @returns The focusable sibling element or null
   */
  findFocusableSibling(
    element: Element,
    direction: "next" | "previous"
  ): HTMLElement | null {
    const siblingProperty =
      direction === "next" ? "nextElementSibling" : "previousElementSibling";
    let sibling = element[siblingProperty];

    while (sibling) {
      if (this.isFocusable(sibling)) {
        // Only HTML elements have the `offsetParent` that `isFocusable` requires.
        return sibling as HTMLElement;
      }
      sibling = sibling[siblingProperty];
    }

    return null;
  }

  /**
   * Checks if an element is focusable
   * @param element - The element to check
   * @returns True if the element is focusable
   */
  isFocusable(element: Element): boolean {
    const tabindex = element.getAttribute("tabindex");
    if (tabindex === "-1") {
      return false;
    }

    if (!(element as HTMLElement).offsetParent) {
      return false;
    }

    if ((element as HTMLElement & { disabled?: boolean }).disabled) {
      return false;
    }

    const focusable = [
      "A",
      "BUTTON",
      "INPUT",
      "SELECT",
      "TEXTAREA",
      "SUMMARY",
    ].includes(element.tagName);

    const hasTabindex = tabindex !== null && tabindex !== "-1";

    return focusable || hasTabindex;
  }

  /**
   * Cleanup method called when the modifier is destroyed
   */
  cleanup() {
    this.element?.removeEventListener("keydown", this.handleKeydown);
  }
}
